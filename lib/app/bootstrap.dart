import 'package:logging/logging.dart';

import '../core/logging/app_log_file_sink.dart';
import '../core/logging/app_logging.dart';
import '../core/update/app_update_platform.dart';

Future<AppLogFileSink> bootstrap() async {
  final sink = await configureAppLogging();
  await _logAppStarted();
  return sink;
}

Future<void> _logAppStarted() async {
  final logger = Logger('app.bootstrap');
  try {
    final version = await const AppUpdatePlatform().getVersionInfo();
    logger.info(
      'SmartFlow started: version ${version.versionName} '
      '(build ${version.buildNumber}).',
    );
  } catch (_) {
    // 平台通道不可用（如桌面调试）时仍记录启动。
    logger.info('SmartFlow started.');
  }
}
