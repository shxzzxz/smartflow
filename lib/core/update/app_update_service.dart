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
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const defaultManifestBaseUrl = 'https://shxzzxz.github.io/smartflow';

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
    } catch (error, stackTrace) {
      _logger.warning(
        'Update manifest fetch failed: $manifestUri',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<AppUpdateInfo?> checkForUpdate({
    required int currentAndroidVersionCode,
    required List<String> supportedAbis,
  }) async {
    final info = await fetchUpdateInfo();
    final installable = info.hasInstallableUpdate(
      currentAndroidVersionCode: currentAndroidVersionCode,
      supportedAbis: supportedAbis,
    );
    _logger.info(
      'Update check completed: latest=${info.versionName} '
      '(build ${info.buildNumber}), channel=${info.channel.code}, '
      'installable=$installable.',
    );
    return installable ? info : null;
  }

  Future<File> downloadApk(
    AppUpdateInfo info, {
    List<String> supportedAbis = const [],
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final package = info.resolvePackage(supportedAbis);
    if (package == null) {
      throw const FormatException('No compatible APK package.');
    }
    final uri = Uri.parse(package.url);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(
        directory.path,
        'smartflow-${info.versionName}-${package.abi}.apk',
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

  Future<void> verifyDownloadedApk(File file, AppUpdatePackage package) async {
    if (!await file.exists()) {
      throw const FileSystemException('Downloaded APK does not exist.');
    }

    final expectedSize = package.size;
    if (expectedSize != null && await file.length() != expectedSize) {
      throw const FormatException('Downloaded APK size mismatch.');
    }

    final expectedHash = package.sha256;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedHash) {
        throw const FormatException('Downloaded APK checksum mismatch.');
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
