import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../application/data_management/backup/backup_archive.dart';
import '../../../application/data_management/backup/backup_models.dart';
import '../../../application/data_management/backup/backup_service.dart';
import '../../../core/error/app_error_code.dart';
import '../../../core/error/app_exception.dart';

enum _BackupArchiveErrorCode implements AppErrorCode {
  pickerFailed(
    code: 'infra.backup.picker_failed',
    defaultMessage: '无法打开文件选择器，请稍后重试。',
  ),
  readFailed(
    code: 'infra.backup.read_failed',
    defaultMessage: '无法读取备份文件，请重新选择。',
  ),
  invalidArchive(
    code: 'infra.backup.invalid_archive',
    defaultMessage: '备份压缩包无效或已损坏，请重新选择。',
  ),
  writeFailed(
    code: 'infra.backup.write_failed',
    defaultMessage: '无法保存备份，请检查文件权限后重试。',
  );

  const _BackupArchiveErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

class PlatformBackupArchive implements BackupArchivePort {
  const PlatformBackupArchive();

  static const _maxArchiveEntries = 256;
  static const _maxArchiveBytes = 512 * 1024 * 1024;
  static const _maxFileBytes = 128 * 1024 * 1024;

  @override
  Future<BackupManifest?> export(BackupService service) async {
    final now = DateTime.now();
    final stamp = _timestamp(now);
    final temporaryDirectory = await getTemporaryDirectory();
    final staging = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}smartflow-backup-$stamp-${now.microsecondsSinceEpoch}',
    );
    try {
      final manifest = await service.createBackup(staging);
      final archiveBytes = await _zipDirectory(staging);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: '保存备份',
        fileName: 'smartflow-backup-$stamp.zip',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: archiveBytes,
      );
      return savedPath == null ? null : manifest;
    } on AppException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _BackupArchiveErrorCode.writeFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await _deleteQuietly(staging);
    }
  }

  @override
  Future<BackupSelection?> pickForRestore() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: '选择 smartflow-backup ZIP 文件',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _BackupArchiveErrorCode.pickerFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (picked.isEmpty) return null;
    final Uint8List bytes;
    try {
      bytes = await picked.single.readAsBytes();
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _BackupArchiveErrorCode.readFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    final parent = await getTemporaryDirectory();
    final Directory staging;
    try {
      staging = await _unzipArchive(bytes, parent);
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _BackupArchiveErrorCode.invalidArchive,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return BackupSelection(
      source: staging,
      dispose: () => _deleteQuietly(staging),
    );
  }

  @override
  Future<BackupDiff> compare(
    BackupService service,
    BackupSelection selection,
  ) => service.compare(selection.source);

  @override
  Future<BackupDiff> restore(
    BackupService service,
    BackupSelection selection,
  ) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final safety = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}smartflow-safety-${DateTime.now().microsecondsSinceEpoch}',
    );
    // Keep a rollback snapshot for the duration of the replacement. The
    // database gateway still owns the atomic transaction; retaining this
    // package until completion protects the live operation from partial work.
    try {
      await service.createBackup(safety);
      return await service.restore(selection.source);
    } finally {
      await _deleteQuietly(safety);
    }
  }

  Future<Uint8List> _zipDirectory(Directory directory) async {
    final archive = Archive();
    final separator = Platform.pathSeparator;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relativePath = entity.path
          .substring(directory.path.length + separator.length)
          .replaceAll(separator, '/');
      archive.add(ArchiveFile.bytes(relativePath, await entity.readAsBytes()));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  Future<Directory> _unzipArchive(List<int> bytes, Directory parent) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final staging = await Directory(
      '${parent.path}${Platform.pathSeparator}smartflow-restore-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    try {
      var entryCount = 0;
      var totalBytes = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (++entryCount > _maxArchiveEntries) {
          throw const FileSystemException('备份 ZIP 文件数量超过限制。');
        }
        final normalized = entry.name.replaceAll('\\', '/');
        if (normalized.startsWith('/') ||
            normalized.split('/').contains('..') ||
            normalized.contains('\u0000') ||
            RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
          throw const FileSystemException('备份 ZIP 包含非法文件路径。');
        }
        final file = File(
          '${staging.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}',
        );
        await file.parent.create(recursive: true);
        final content = entry.readBytes();
        if (content == null) {
          throw FileSystemException('无法读取 ZIP 文件项: ${entry.name}');
        }
        if (content.length > _maxFileBytes ||
            (totalBytes += content.length) > _maxArchiveBytes) {
          throw const FileSystemException('备份 ZIP 解压大小超过限制。');
        }
        await file.writeAsBytes(content, flush: true);
      }
      return staging;
    } catch (_) {
      await _deleteQuietly(staging);
      rethrow;
    }
  }

  Future<void> _deleteQuietly(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}

String _timestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${value.year.toString().padLeft(4, '0')}'
      '${twoDigits(value.month)}${twoDigits(value.day)}'
      '${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
}
