import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_update_channel.dart';
import 'app_update_info.dart';

class AppUpdateService {
  AppUpdateService({
    required this.manifestUri,
    this.expectedChannel,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const defaultManifestBaseUrl =
      'https://shxzzxz.github.io/smartflow';

  final Uri manifestUri;
  final AppUpdateChannel? expectedChannel;
  final HttpClient Function() _httpClientFactory;

  static Uri manifestUriForChannel(
    AppUpdateChannel channel, {
    String baseUrl = defaultManifestBaseUrl,
  }) {
    return Uri.parse('$baseUrl/update-${channel.code}.json');
  }

  Future<AppUpdateInfo> fetchUpdateInfo() async {
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(manifestUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'SmartFlow');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Update manifest request failed: ${response.statusCode}.',
          uri: manifestUri,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, Object?>) {
        throw const FormatException('Update manifest must be a JSON object.');
      }

      final info = AppUpdateInfo.fromJson(json);
      final channel = expectedChannel;
      if (channel != null && info.channel != channel) {
        throw FormatException(
          'Update manifest channel mismatch: expected ${channel.code}, '
          'got ${info.channel.code}.',
        );
      }
      return info;
    } finally {
      client.close(force: true);
    }
  }

  Future<AppUpdateInfo?> checkForUpdate({
    required int currentBuildNumber,
  }) async {
    final info = await fetchUpdateInfo();
    return info.isNewerThan(currentBuildNumber) ? info : null;
  }

  Future<File> downloadApk(
    AppUpdateInfo info, {
    List<String> supportedAbis = const [],
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final package = info.resolvePackage(supportedAbis);
    final uri = Uri.parse(package.url);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(
        directory.path,
        package.abi == 'universal'
            ? 'smartflow-${info.versionName}.apk'
            : 'smartflow-${info.versionName}-${package.abi}.apk',
      ),
    );

    final client = _httpClientFactory();
    IOSink? sink;
    final digestCollector = _DigestSink();
    final digestSink = sha256.startChunkedConversion(digestCollector);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'SmartFlow');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'APK request failed: ${response.statusCode}.',
          uri: uri,
        );
      }

      final totalBytes =
          response.contentLength >= 0 ? response.contentLength : null;
      var receivedBytes = 0;
      sink = file.openWrite();

      await for (final chunk in response) {
        receivedBytes += chunk.length;
        digestSink.add(chunk);
        sink.add(chunk);
        onProgress?.call(
          AppUpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      digestSink.close();
      await sink.close();
      sink = null;
      final expectedSize = package.size;
      if (expectedSize != null && receivedBytes != expectedSize) {
        await file.delete().catchError((_) => file);
        throw const FormatException('Downloaded APK size mismatch.');
      }
      final expectedHash = package.sha256;
      if (expectedHash != null &&
          expectedHash.isNotEmpty &&
          digestCollector.digest.toString().toLowerCase() != expectedHash) {
        await file.delete().catchError((_) => file);
        throw const FormatException('Downloaded APK checksum mismatch.');
      }
      return file;
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest {
    final digest = _digest;
    if (digest == null) {
      throw StateError('Digest is not ready.');
    }
    return digest;
  }

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}
