import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final channel = _required(options, 'channel');
  final versionName = _required(options, 'version-name');
  final versionCode = int.tryParse(_required(options, 'version-code'));
  final tag = _required(options, 'tag');
  final repository = _required(options, 'repository');
  final assetDir = Directory(_required(options, 'asset-dir'));
  final outputDir = Directory(_required(options, 'output-dir'));

  if (versionCode == null || versionCode <= 0) {
    throw const FormatException('--version-code must be a positive integer.');
  }
  if (!assetDir.existsSync()) {
    throw FileSystemException('Asset directory does not exist.', assetDir.path);
  }
  outputDir.createSync(recursive: true);

  final universal = File('${assetDir.path}/smartflow-$versionName.apk');
  if (!universal.existsSync()) {
    throw FileSystemException('Universal APK does not exist.', universal.path);
  }

  final releaseUrl = 'https://github.com/$repository/releases/tag/$tag';
  final downloadBase = 'https://github.com/$repository/releases/download/$tag';
  final universalStats = await _apkStats(universal);

  final manifest = <String, Object?>{
    'channel': channel,
    'versionName': versionName,
    'versionCode': versionCode,
    'tag': tag,
    'releaseType': _releaseTypeFor(channel),
    'apkUrl': '$downloadBase/${_fileName(universal)}',
    'apkSha256': universalStats.sha256,
    'apkSize': universalStats.size,
    'releaseUrl': releaseUrl,
    'required': false,
    'notes': _notesFor(channel, versionName),
    'apks': await _splitApks(assetDir, versionName, downloadBase),
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
) async {
  final packages = <Map<String, Object?>>[];
  for (final abi in const ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
    final apk = File('${assetDir.path}/smartflow-$versionName-$abi.apk');
    if (!apk.existsSync()) {
      continue;
    }
    final stats = await _apkStats(apk);
    packages.add({
      'abi': abi,
      'url': '$downloadBase/${_fileName(apk)}',
      'sha256': stats.sha256,
      'size': stats.size,
    });
  }
  return packages;
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
