import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../application/import/import_file_picker.dart';
import '../../core/error/app_error_code.dart';
import '../../core/error/app_exception.dart';
import '../../domain/import/import_models.dart';

enum _ImportFilePickerErrorCode implements AppErrorCode {
  pickFailed(
    code: 'infra.import_file.pick_failed',
    defaultMessage: '无法打开文件选择器，请稍后重试。',
  ),
  readFailed(
    code: 'infra.import_file.read_failed',
    defaultMessage: '无法读取所选文件，请重新选择。',
  );

  const _ImportFilePickerErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

class PlatformImportFilePicker implements ImportFilePicker {
  const PlatformImportFilePicker();

  @override
  Future<ImportBundle?> pickYimuBundle() async {
    final List<PlatformFile> result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
      );
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _ImportFilePickerErrorCode.pickFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (result.isEmpty) return null;

    final files = <ImportFilePayload>[];
    for (final file in result) {
      late final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } on Exception catch (error, stackTrace) {
        throw InfrastructureException(
          _ImportFilePickerErrorCode.readFailed,
          cause: error,
          stackTrace: stackTrace,
          message: '无法读取文件 ${file.name}，请重新选择。',
        );
      }
      files.add(ImportFilePayload(name: file.name, bytes: bytes));
    }
    return ImportBundle(files: files);
  }
}
