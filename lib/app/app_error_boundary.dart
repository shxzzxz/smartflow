import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../design_system/theme/app_text_styles.dart';
import '../design_system/token/spacing.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppGlobalErrorHandler {
  AppGlobalErrorHandler({
    required this.scaffoldMessengerKey,
    Logger? logger,
    this.showDebugDetails = kDebugMode,
  }) : _logger = logger ?? Logger('app.error');

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final bool showDebugDetails;
  final Logger _logger;

  void install() {
    FlutterError.onError = handleFlutterError;
    ErrorWidget.builder = buildErrorWidget;
    PlatformDispatcher.instance.onError = handlePlatformError;
  }

  void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logger.severe(
      'Flutter framework error.',
      details.exception,
      details.stack,
    );
  }

  bool handlePlatformError(Object error, StackTrace stackTrace) {
    _logger.severe('Unhandled async error.', error, stackTrace);
    showUnexpectedErrorSnackBar();
    return true;
  }

  void handleZoneError(Object error, StackTrace stackTrace) {
    _logger.severe('Unhandled zone error.', error, stackTrace);
    showUnexpectedErrorSnackBar();
  }

  Widget buildErrorWidget(FlutterErrorDetails details) {
    return AppErrorFallbackView(
      details: details,
      showDebugDetails: showDebugDetails,
    );
  }

  void showUnexpectedErrorSnackBar() {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('发生了未预期错误，请稍后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class AppErrorFallbackView extends StatelessWidget {
  const AppErrorFallbackView({
    required this.details,
    required this.showDebugDetails,
    super.key,
  });

  final FlutterErrorDetails details;
  final bool showDebugDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: colors.error,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  Text(
                    '页面出错了',
                    style: textStyles.sectionTitleStrong,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    '请稍后重试',
                    style: textStyles.pageSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  if (showDebugDetails) ...[
                    const SizedBox(height: AppSpacing.space16),
                    SelectableText(
                      details.exceptionAsString(),
                      style: textStyles.listSupporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
