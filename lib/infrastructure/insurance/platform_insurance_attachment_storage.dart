import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../application/insurance/attachment/port/insurance_attachment_storage.dart';
import '../../core/error/app_error_code.dart';
import '../../core/error/app_exception.dart';
import '../../core/id/id_generator.dart';

final _logger = Logger('infra.insurance');

enum _AttachmentStorageErrorCode implements AppErrorCode {
  pickFailed(
    code: 'infra.insurance_attachment.pick_failed',
    defaultMessage: '无法打开文件选择器，请稍后重试。',
  ),
  copyFailed(
    code: 'infra.insurance_attachment.copy_failed',
    defaultMessage: '无法保存合同附件，请重新选择。',
  ),
  openFailed(
    code: 'infra.insurance_attachment.open_failed',
    defaultMessage: '当前设备无法打开该附件。',
  ),
  deleteFailed(
    code: 'infra.insurance_attachment.delete_failed',
    defaultMessage: '无法删除合同附件文件。',
  ),
  invalidStorageKey(
    code: 'infra.insurance_attachment.invalid_storage_key',
    defaultMessage: '合同附件存储位置无效。',
  );

  const _AttachmentStorageErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

Future<List<PlatformFile>> _pickInsuranceFiles() => FilePicker.pickFiles();

Future<Directory> _applicationSupportDirectory() =>
    getApplicationSupportDirectory();

class PlatformInsuranceAttachmentStorage implements InsuranceAttachmentStorage {
  PlatformInsuranceAttachmentStorage({
    required IdGenerator ids,
    Future<List<PlatformFile>> Function()? pickFiles,
    Future<Directory> Function()? supportDirectory,
  }) : _ids = ids,
       _pickFiles = pickFiles ?? _pickInsuranceFiles,
       _supportDirectory = supportDirectory ?? _applicationSupportDirectory;

  final IdGenerator _ids;
  final Future<List<PlatformFile>> Function() _pickFiles;
  final Future<Directory> Function() _supportDirectory;

  static const _storageFolder = 'insurance_attachments';

  @override
  Future<List<InsuranceAttachmentDraft>> pickAndStore({
    required String commercialInsuranceId,
  }) async {
    final List<PlatformFile> files;
    try {
      files = await _pickFiles();
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.pickFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (files.isEmpty) return const [];

    final support = await _supportDirectory();
    final targetDirectory = Directory(
      path.join(
        support.path,
        _storageFolder,
        _safeSegment(commercialInsuranceId),
      ),
    );
    try {
      await targetDirectory.create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.copyFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final drafts = <InsuranceAttachmentDraft>[];
    final createdFiles = <File>[];
    try {
      for (final file in files) {
        final safeName = _safeFileName(file.name);
        final storedName = '${_ids.newId()}_$safeName';
        final destination = File(path.join(targetDirectory.path, storedName));
        try {
          if (!await destination.exists()) createdFiles.add(destination);
          final sourcePath = file.path;
          if (sourcePath != null) {
            await File(sourcePath).copy(destination.path);
          } else {
            await destination.writeAsBytes(
              await file.readAsBytes(),
              flush: true,
            );
          }
        } on Exception catch (error, stackTrace) {
          throw InfrastructureException(
            _AttachmentStorageErrorCode.copyFailed,
            message: '无法保存附件 ${file.name}，请重新选择。',
            cause: error,
            stackTrace: stackTrace,
          );
        }
        drafts.add(
          InsuranceAttachmentDraft(
            fileName: file.name,
            storageKey: path.join(
              _storageFolder,
              _safeSegment(commercialInsuranceId),
              storedName,
            ),
            mimeType: _mimeTypeFor(file.name),
          ),
        );
      }
      return drafts;
    } catch (error, stackTrace) {
      await _cleanupFiles(createdFiles);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> open(String storageKey) async {
    final file = await _resolveFile(storageKey);
    if (!await file.exists()) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.openFailed,
        message: '附件文件不存在或已损坏。',
      );
    }
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw InfrastructureException(
          _AttachmentStorageErrorCode.openFailed,
          message: result.message.isEmpty
              ? _AttachmentStorageErrorCode.openFailed.defaultMessage
              : result.message,
        );
      }
    } on InfrastructureException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.openFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    final file = await _resolveFile(storageKey);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error, stackTrace) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.deleteFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<File> _resolveFile(String storageKey) async {
    final trimmed = storageKey.trim();
    if (trimmed.isEmpty ||
        path.isAbsolute(trimmed) ||
        trimmed.split(RegExp(r'[/\\]')).contains('..')) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.invalidStorageKey,
      );
    }
    final support = await _supportDirectory();
    final storageRoot = path.normalize(path.join(support.path, _storageFolder));
    final resolved = path.normalize(path.join(support.path, trimmed));
    if (!path.isWithin(storageRoot, resolved)) {
      throw InfrastructureException(
        _AttachmentStorageErrorCode.invalidStorageKey,
      );
    }
    return File(resolved);
  }

  Future<void> _cleanupFiles(Iterable<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (error, stackTrace) {
        _logger.warning(
          'Failed to clean up a partially stored insurance attachment.',
          error,
          stackTrace,
        );
      }
    }
  }

  String _safeSegment(String value) {
    final normalized = value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    if (normalized.isEmpty || normalized == '.' || normalized == '..') {
      return _ids.newId();
    }
    return normalized;
  }

  String _safeFileName(String value) {
    final basename = path.basename(value).trim();
    final normalized = basename.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    if (normalized.isEmpty || normalized == '.' || normalized == '..') {
      return 'attachment';
    }
    return normalized.length <= 120
        ? normalized
        : normalized.substring(normalized.length - 120);
  }

  String _mimeTypeFor(String fileName) {
    return switch (path.extension(fileName).toLowerCase()) {
      '.pdf' => 'application/pdf',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.txt' => 'text/plain',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }
}
