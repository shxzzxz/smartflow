import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../application/data_management/icons/port/user_business_icon_store.dart';
import '../../../application/data_management/icons/user_business_icon_models.dart';
import '../../../core/error/app_error_code.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/id/id_generator.dart';

final _logger = Logger('infra.data_management.icons');

const backupBusinessIconPrefix = 'business_icons';
const _manifestName = 'manifest.json';
const _iconSize = 256;
const _maxInputBytes = 16 * 1024 * 1024;
const _supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

enum _UserBusinessIconErrorCode implements AppErrorCode {
  pickFailed(
    code: 'infra.data_management.icons.pick_failed',
    defaultMessage: '无法打开图片选择器，请稍后重试。',
  ),
  unsupportedFormat(
    code: 'infra.data_management.icons.unsupported_format',
    defaultMessage: '仅支持 PNG、JPEG 或 WebP 图片。',
  ),
  inputTooLarge(
    code: 'infra.data_management.icons.input_too_large',
    defaultMessage: '图片文件过大，请选择 16 MB 以内的图片。',
  ),
  animatedImage(
    code: 'infra.data_management.icons.animated',
    defaultMessage: '图标不能使用动图，请选择静态图片。',
  ),
  decodeFailed(
    code: 'infra.data_management.icons.decode_failed',
    defaultMessage: '无法读取该图片，请重新选择。',
  ),
  saveFailed(
    code: 'infra.data_management.icons.save_failed',
    defaultMessage: '无法保存图标，请稍后重试。',
  ),
  deleteFailed(
    code: 'infra.data_management.icons.delete_failed',
    defaultMessage: '无法删除图标，请稍后重试。',
  ),
  invalidManifest(
    code: 'infra.data_management.icons.invalid_manifest',
    defaultMessage: '图标清单已损坏，无法管理自定义图标。',
  ),
  invalidBackup(
    code: 'infra.data_management.icons.invalid_backup',
    defaultMessage: '备份中的用户图标数据无效。',
  );

  const _UserBusinessIconErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

class PickedUserBusinessIcon {
  const PickedUserBusinessIcon({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedUserBusinessIcon?> _pickUserIcon() async {
  final files = await FilePicker.pickFiles(
    dialogTitle: '选择图标图片',
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
  );
  if (files.isEmpty) return null;
  final file = files.single;
  return PickedUserBusinessIcon(
    name: file.name,
    bytes: await file.readAsBytes(),
  );
}

Future<Directory> _applicationSupportDirectory() =>
    getApplicationSupportDirectory();

class PlatformUserBusinessIconStore implements UserBusinessIconStore {
  PlatformUserBusinessIconStore({
    required IdGenerator ids,
    Future<Directory> Function()? supportDirectory,
    Future<PickedUserBusinessIcon?> Function()? pickImage,
  }) : _ids = ids,
       _supportDirectory = supportDirectory ?? _applicationSupportDirectory,
       _pickImage = pickImage ?? _pickUserIcon;

  final IdGenerator _ids;
  final Future<Directory> Function() _supportDirectory;
  final Future<PickedUserBusinessIcon?> Function() _pickImage;

  @override
  Future<List<UserBusinessIconRecord>> load() async {
    final root = await _root();
    return _loadRecords(root);
  }

  @override
  Future<UserBusinessIconRecord?> pickAndStore(
    UserBusinessIconType type,
  ) async {
    final PickedUserBusinessIcon? picked;
    try {
      picked = await _pickImage();
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _UserBusinessIconErrorCode.pickFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (picked == null) return null;
    if (!_supportedExtensions.contains(
      path.extension(picked.name).toLowerCase(),
    )) {
      throw InfrastructureException(
        _UserBusinessIconErrorCode.unsupportedFormat,
      );
    }
    if (picked.bytes.length > _maxInputBytes) {
      throw InfrastructureException(_UserBusinessIconErrorCode.inputTooLarge);
    }

    final normalized = await _normalize(picked.bytes);
    final root = await _root();
    final records = await _loadRecords(root);
    final key = _newUniqueKey(records);
    final relativePath = path.join('icons', type.wireName, '$key.png');
    final iconFile = File(path.join(root.path, relativePath));
    final record = UserBusinessIconRecord(
      type: type,
      key: key,
      label: _labelFor(picked.name),
      filePath: iconFile.path,
      createdAt: DateTime.now().toUtc(),
    );
    try {
      await iconFile.parent.create(recursive: true);
      await iconFile.writeAsBytes(normalized, flush: true);
      await _writeManifest(root, [...records, record]);
    } on Exception catch (error, stackTrace) {
      try {
        if (await iconFile.exists()) await iconFile.delete();
      } on FileSystemException {
        // The failed upload remains an unreferenced file if cleanup is blocked.
      }
      if (error is InfrastructureException) rethrow;
      throw InfrastructureException(
        _UserBusinessIconErrorCode.saveFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return record;
  }

  @override
  Future<void> delete(UserBusinessIconRecord icon) async {
    final root = await _root();
    final records = await _loadRecords(root);
    final remaining = [
      for (final record in records)
        if (record.refId != icon.refId) record,
    ];
    if (remaining.length == records.length) return;
    try {
      await _writeManifest(root, remaining);
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _UserBusinessIconErrorCode.deleteFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    try {
      final file = File(icon.filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        'Failed to delete an orphaned user icon file after manifest update.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<Map<String, Uint8List>> exportBackupFiles() async {
    final root = await _root();
    final records = await _loadRecords(root);
    if (records.isEmpty) return const {};
    final manifest = File(path.join(root.path, _manifestName));
    if (!await manifest.exists()) return const {};
    final files = <String, Uint8List>{
      '$backupBusinessIconPrefix/$_manifestName': await manifest.readAsBytes(),
    };
    for (final record in records) {
      final file = File(record.filePath);
      if (!await file.exists()) continue;
      final relative = path.relative(file.path, from: root.path);
      files['$backupBusinessIconPrefix/${relative.replaceAll('\\', '/')}'] =
          await file.readAsBytes();
    }
    return files;
  }

  @override
  Future<void> restoreBackupFiles(Map<String, Uint8List> files) async {
    final support = await _supportDirectory();
    final root = Directory(path.join(support.path, 'user_icons'));
    if (files.isEmpty) {
      await _deleteDirectory(root);
      return;
    }
    for (final key in files.keys) {
      if (!_isValidBackupPath(key)) {
        throw InfrastructureException(_UserBusinessIconErrorCode.invalidBackup);
      }
    }
    final manifestKey = '$backupBusinessIconPrefix/$_manifestName';
    if (!files.containsKey(manifestKey)) {
      throw InfrastructureException(_UserBusinessIconErrorCode.invalidBackup);
    }

    final staging = Directory(
      path.join(support.path, 'user_icons.restore-${_ids.newId()}'),
    );
    final previous = Directory(
      path.join(support.path, 'user_icons.previous-${_ids.newId()}'),
    );
    try {
      await staging.create(recursive: true);
      for (final entry in files.entries) {
        final relative = entry.key.substring(
          backupBusinessIconPrefix.length + 1,
        );
        final file = File(path.joinAll([staging.path, ...relative.split('/')]));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value, flush: true);
      }
      try {
        await _loadRecords(staging, requireAllFiles: true);
      } on InfrastructureException catch (error, stackTrace) {
        throw InfrastructureException(
          _UserBusinessIconErrorCode.invalidBackup,
          cause: error,
          stackTrace: stackTrace,
        );
      }

      if (await root.exists()) await root.rename(previous.path);
      await staging.rename(root.path);
      await _deleteDirectory(previous);
    } catch (error, stackTrace) {
      if (await previous.exists()) {
        await _deleteDirectory(root);
        await previous.rename(root.path);
      }
      await _deleteDirectory(staging);
      if (error is InfrastructureException) rethrow;
      throw InfrastructureException(
        _UserBusinessIconErrorCode.saveFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Directory> _root() async {
    final support = await _supportDirectory();
    return Directory(path.join(support.path, 'user_icons'));
  }

  Future<List<UserBusinessIconRecord>> _loadRecords(
    Directory root, {
    bool requireAllFiles = false,
  }) async {
    final manifest = File(path.join(root.path, _manifestName));
    if (!await manifest.exists()) return const [];
    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['icons'] is! List) {
        throw const FormatException('Invalid user icon manifest.');
      }
      final records = <UserBusinessIconRecord>[];
      final identities = <String>{};
      for (final raw in decoded['icons'] as List) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid user icon record.');
        }
        final type = UserBusinessIconTypeValue.parse('${raw['type']}');
        final key = '${raw['key']}';
        final label = '${raw['label']}'.trim();
        final createdAt = DateTime.tryParse('${raw['createdAt']}');
        if (!_isIdentifier(key) ||
            label.isEmpty ||
            createdAt == null ||
            !identities.add('${type.wireName}:$key')) {
          throw const FormatException('Invalid user icon record.');
        }
        final file = File(
          path.join(root.path, 'icons', type.wireName, '$key.png'),
        );
        if (!await file.exists()) {
          if (requireAllFiles) {
            throw const FormatException('Missing user icon file.');
          }
          _logger.warning(
            'User icon file is missing for ${type.wireName}:$key.',
          );
          continue;
        }
        records.add(
          UserBusinessIconRecord(
            type: type,
            key: key,
            label: label,
            filePath: file.path,
            createdAt: createdAt,
          ),
        );
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(records);
    } on InfrastructureException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _UserBusinessIconErrorCode.invalidManifest,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeManifest(
    Directory root,
    List<UserBusinessIconRecord> records,
  ) async {
    await root.create(recursive: true);
    final manifest = File(path.join(root.path, _manifestName));
    final temporary = File(
      path.join(root.path, '$_manifestName.tmp-${_ids.newId()}'),
    );
    final previous = File(
      path.join(root.path, '$_manifestName.previous-${_ids.newId()}'),
    );
    final payload = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'icons': [
        for (final record in records)
          {
            'type': record.type.wireName,
            'key': record.key,
            'label': record.label,
            'createdAt': record.createdAt.toUtc().toIso8601String(),
          },
      ],
    });
    await temporary.writeAsString('$payload\n', flush: true);
    try {
      if (await manifest.exists()) await manifest.rename(previous.path);
      await temporary.rename(manifest.path);
    } catch (_) {
      if (await previous.exists()) {
        if (await manifest.exists()) await manifest.delete();
        await previous.rename(manifest.path);
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    try {
      if (await previous.exists()) await previous.delete();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        'Failed to remove the previous user icon manifest.',
        error,
        stackTrace,
      );
    }
  }

  Future<Uint8List> _normalize(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? source;
    ui.Image? output;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _iconSize,
        allowUpscaling: false,
      );
      if (codec.frameCount != 1) {
        throw InfrastructureException(_UserBusinessIconErrorCode.animatedImage);
      }
      source = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final scale = math.min(
        _iconSize / source.width,
        _iconSize / source.height,
      );
      final width = source.width * scale;
      final height = source.height * scale;
      final destination = ui.Rect.fromLTWH(
        (_iconSize - width) / 2,
        (_iconSize - height) / 2,
        width,
        height,
      );
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        destination,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      output = await picture.toImage(_iconSize, _iconSize);
      picture.dispose();
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw InfrastructureException(_UserBusinessIconErrorCode.decodeFailed);
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on InfrastructureException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        _UserBusinessIconErrorCode.decodeFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      source?.dispose();
      output?.dispose();
      codec?.dispose();
    }
  }

  String _newUniqueKey(List<UserBusinessIconRecord> records) {
    final existing = {for (final record in records) record.key};
    while (true) {
      final key = _ids.newId();
      if (_isIdentifier(key) && existing.add(key)) return key;
    }
  }

  String _labelFor(String fileName) {
    final value = path.basenameWithoutExtension(fileName).trim();
    if (value.isEmpty) return '自定义图标';
    return value.length <= 80 ? value : value.substring(0, 80);
  }

  bool _isValidBackupPath(String value) {
    if (!value.startsWith('$backupBusinessIconPrefix/') ||
        value.contains('\\') ||
        value.contains('\u0000') ||
        value.split('/').contains('..')) {
      return false;
    }
    final relative = value.substring(backupBusinessIconPrefix.length + 1);
    if (relative == _manifestName) return true;
    final parts = relative.split('/');
    return parts.length == 3 &&
        parts[0] == 'icons' &&
        (parts[1] == 'account' || parts[1] == 'category') &&
        _isIdentifier(path.basenameWithoutExtension(parts[2])) &&
        path.extension(parts[2]).toLowerCase() == '.png';
  }
}

bool _isIdentifier(String value) =>
    RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(value);

Future<void> _deleteDirectory(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException catch (error, stackTrace) {
    _logger.warning(
      'Failed to clean up a user icon directory.',
      error,
      stackTrace,
    );
  }
}
