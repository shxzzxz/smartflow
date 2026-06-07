import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final channel = _required(options, 'channel');
  final versionName = _required(options, 'version-name');
  final buildNumber = int.tryParse(_required(options, 'version-code'));
  final tag = _required(options, 'tag');
  final repository = _required(options, 'repository');
  final assetDir = Directory(_required(options, 'asset-dir'));
  final apkMetadata = File(_required(options, 'apk-metadata'));
  final outputDir = Directory(_required(options, 'output-dir'));

  if (buildNumber == null || buildNumber <= 0) {
    throw const FormatException('--version-code must be a positive integer.');
  }
  if (!assetDir.existsSync()) {
    throw FileSystemException('Asset directory does not exist.', assetDir.path);
  }
  if (!apkMetadata.existsSync()) {
    throw FileSystemException(
      'APK output metadata does not exist.',
      apkMetadata.path,
    );
  }
  outputDir.createSync(recursive: true);

  final universal = File('${assetDir.path}/smartflow-$versionName.apk');
  if (!universal.existsSync()) {
    throw FileSystemException('Universal APK does not exist.', universal.path);
  }

  final releaseUrl = 'https://github.com/$repository/releases/tag/$tag';
  final downloadBase = 'https://github.com/$repository/releases/download/$tag';
  final universalStats = await _apkStats(universal);
  final splitVersionCodes = _readSplitVersionCodes(apkMetadata);

  final manifest = <String, Object?>{
    'channel': channel,
    'versionName': versionName,
    'buildNumber': buildNumber,
    'tag': tag,
    'releaseType': _releaseTypeFor(channel),
    'releaseUrl': releaseUrl,
    'required': false,
    'notes': _notesFor(channel, versionName),
    'universalApk': {
      'url': '$downloadBase/${_fileName(universal)}',
      'sha256': universalStats.sha256,
      'size': universalStats.size,
      'androidVersionCode': buildNumber,
    },
    'apks': await _splitApks(
      assetDir,
      versionName,
      downloadBase,
      splitVersionCodes,
    ),
  };

  final output = File('${outputDir.path}/update-$channel.json');
  const encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync('${encoder.convert(manifest)}\n');
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      throw FormatException('Unexpected argument: $arg');
    }
    final key = arg.substring(2);
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      throw FormatException('Missing value for $arg.');
    }
    options[key] = args[++i];
  }
  return options;
}

String _required(Map<String, String> options, String key) {
  final value = options[key];
  if (value == null || value.trim().isEmpty) {
    throw FormatException('Missing required option --$key.');
  }
  return value.trim();
}

String _releaseTypeFor(String channel) {
  return switch (channel) {
    'stable' => 'release',
    'beta' => 'prerelease',
    'dev' => 'prerelease',
    _ => 'prerelease',
  };
}

String _notesFor(String channel, String versionName) {
  final label = switch (channel) {
    'stable' => '稳定',
    'beta' => '尝鲜',
    'dev' => '开发',
    _ => channel,
  };
  return 'SmartFlow $versionName $label渠道版本。';
}

Future<List<Map<String, Object?>>> _splitApks(
  Directory assetDir,
  String versionName,
  String downloadBase,
  Map<String, int> splitVersionCodes,
) async {
  final packages = <Map<String, Object?>>[];
  for (final abi in const ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
    final apk = File('${assetDir.path}/smartflow-$versionName-$abi.apk');
    if (!apk.existsSync()) {
      continue;
    }
    final androidVersionCode = splitVersionCodes[abi];
    if (androidVersionCode == null || androidVersionCode <= 0) {
      throw FormatException('Missing Android versionCode for $abi split APK.');
    }
    final stats = await _apkStats(apk);
    packages.add({
      'abi': abi,
      'url': '$downloadBase/${_fileName(apk)}',
      'sha256': stats.sha256,
      'size': stats.size,
      'androidVersionCode': androidVersionCode,
    });
  }
  return packages;
}

Map<String, int> _readSplitVersionCodes(File metadata) {
  final decoded = jsonDecode(metadata.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('APK output metadata must be a JSON object.');
  }

  final elements = decoded['elements'];
  if (elements is! List) {
    throw const FormatException('APK output metadata must include elements.');
  }

  final versionCodes = <String, int>{};
  for (final element in elements.whereType<Map<String, Object?>>()) {
    final abi = _readAbiFilter(element['filters']);
    final versionCode = _readInt(element, 'versionCode');
    if (abi != null && versionCode > 0) {
      versionCodes[abi] = versionCode;
    }
  }

  if (versionCodes.isEmpty) {
    throw const FormatException(
      'APK output metadata does not contain ABI split version codes.',
    );
  }
  return versionCodes;
}

String? _readAbiFilter(Object? filters) {
  if (filters is! List) {
    return null;
  }

  for (final filter in filters.whereType<Map<String, Object?>>()) {
    if (_readString(filter, 'filterType') == 'ABI') {
      final value = _readString(filter, 'value');
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value.trim() : '';
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

Future<_ApkStats> _apkStats(File file) async {
  final hash = await sha256.bind(file.openRead()).first;
  return _ApkStats(sha256: hash.toString(), size: file.lengthSync());
}

String _fileName(File file) {
  return file.uri.pathSegments.last;
}

class _ApkStats {
  const _ApkStats({required this.sha256, required this.size});

  final String sha256;
  final int size;
}
