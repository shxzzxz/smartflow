import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../application/data_management/backup/backup_models.dart';

/// Filesystem adapter for the logical backup package.
class FileBackupPackageStore implements BackupPackageStore {
  const FileBackupPackageStore();

  @override
  Future<void> write(Object destination, BackupPackage package) async {
    final directory = _directory(destination);
    await directory.create(recursive: true);
    for (final entry in package.files.entries) {
      final file = _resolve(directory, entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    final manifest = _resolve(directory, 'manifest.json');
    await manifest.writeAsString('${package.manifest.encode()}\n', flush: true);
  }

  @override
  Future<BackupPackage> read(Object source) async {
    final directory = _directory(source);
    final manifestFile = _resolve(directory, 'manifest.json');
    if (!await manifestFile.exists()) {
      throw const BackupValidationException('备份缺少 manifest.json。');
    }
    final manifest = BackupManifest.fromJson(
      jsonDecode(await manifestFile.readAsString()),
    );
    final files = <String, List<int>>{};
    for (final descriptor in manifest.files) {
      final file = _resolve(directory, descriptor.path);
      if (!await file.exists()) {
        throw BackupValidationException('备份缺少文件: ${descriptor.path}');
      }
      files[descriptor.path] = await file.readAsBytes();
    }
    return BackupPackage(
      manifest: manifest,
      files: {
        for (final entry in files.entries)
          entry.key: Uint8List.fromList(entry.value),
      },
    );
  }

  Directory _directory(Object location) {
    if (location is Directory) return location;
    if (location is String) return Directory(location);
    throw ArgumentError.value(location, 'location');
  }

  File _resolve(Directory root, String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.split('/').contains('..') ||
        normalized.contains('\u0000') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      throw const BackupValidationException('备份文件路径非法。');
    }
    return File(
      '${root.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}',
    );
  }
}
