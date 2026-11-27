import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_update_channel.dart';
import 'app_update_info.dart';

final _logger = Logger('core.update');

class AppUpdateService {
  AppUpdateService({
    required this.manifestUri,
    this.expectedChannel,
    this.requestTimeout = const Duration(seconds: 15),
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const defaultManifestBaseUrl = 'https://shxzzxz.github.io/smartflow';

  final Uri manifestUri;
  final AppUpdateChannel? expectedChannel;
  final Duration requestTimeout;
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
      final request = await client.getUrl(manifestUri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'SmartFlow');
      final response = await request.close().timeout(requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Update manifest request failed: ${response.statusCode}.',
          uri: manifestUri,
        );
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(requestTimeout);
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
    final newer = info.hasNewerBuild(currentBuildNumber);
    _logger.info(
      'Update check completed: currentBuild=$currentBuildNumber, '
      'latest=${info.versionName} (build ${info.buildNumber}), '
      'channel=${info.channel.code}, newerBuild=$newer.',
    );
    return newer ? info : null;
  }

  Future<File> downloadPackage(
    AppUpdatePackage package, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final uri = Uri.parse(package.url);
    final directory = await getTemporaryDirectory();
    final fileName = path.basename(uri.path);
    final file = File(
      path.join(directory.path, fileName.isEmpty ? 'update.bin' : fileName),
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
          'Package request failed: ${response.statusCode}.',
          uri: uri,
        );
      }

      final totalBytes = response.contentLength >= 0
          ? response.contentLength
          : null;
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
        throw const FormatException('Downloaded package size mismatch.');
      }
      final expectedHash = package.sha256;
      if (expectedHash != null &&
          expectedHash.isNotEmpty &&
          digestCollector.digest.toString().toLowerCase() != expectedHash) {
        await file.delete().catchError((_) => file);
        throw const FormatException('Downloaded package checksum mismatch.');
      }
      return file;
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  Future<void> verifyDownloadedPackage(
    File file,
    AppUpdatePackage package,
  ) async {
    if (!await file.exists()) {
      throw const FileSystemException('Downloaded package does not exist.');
    }

    final expectedSize = package.size;
    if (expectedSize != null && await file.length() != expectedSize) {
      throw const FormatException('Downloaded package size mismatch.');
    }

    final expectedHash = package.sha256;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedHash) {
        throw const FormatException('Downloaded package checksum mismatch.');
      }
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
