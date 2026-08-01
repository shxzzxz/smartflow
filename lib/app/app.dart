import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../design_system/theme/app_theme.dart';
import 'app_error_boundary.dart';
import 'provider.dart';
import 'router.dart';

final _navigationLogger = Logger('app.navigation');

class SmartFlowApp extends ConsumerStatefulWidget {
  const SmartFlowApp({super.key, this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  ConsumerState<SmartFlowApp> createState() => _SmartFlowAppState();
}

class _SmartFlowAppState extends ConsumerState<SmartFlowApp>
    with WidgetsBindingObserver {
  String? _lastLoggedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routerDelegate.addListener(_logNavigation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
      unawaited(_applyLogRetentionSettings());
    });
  }

  /// 日志在数据库可用前初始化，持久化的保留设置需在启动后补应用。
  Future<void> _applyLogRetentionSettings() async {
    try {
      final settings = await ref.read(logRetentionStoreProvider).read();
      await ref
          .read(appLogFileSinkProvider)
          .applyRetention(
            maxFiles: settings.maxFiles,
            maxFileAge: settings.maxFileAge,
          );
    } catch (error, stackTrace) {
      Logger(
        'app.logging',
      ).warning('Failed to apply log retention settings.', error, stackTrace);
    }
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_logNavigation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _logNavigation() {
    final location =
        appRouter.routerDelegate.currentConfiguration.uri.toString();
    if (location == _lastLoggedLocation) return;
    _lastLoggedLocation = location;
    _navigationLogger.info('Navigated to $location');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: widget.scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        ErrorWidget.builder =
            AppGlobalErrorHandler(
              scaffoldMessengerKey:
                  widget.scaffoldMessengerKey ?? appScaffoldMessengerKey,
            ).buildErrorWidget;
        return child ?? const SizedBox.shrink();
      },
      routerConfig: appRouter,
    );
  }
}
