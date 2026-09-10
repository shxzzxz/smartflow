import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../design_system/theme/app_theme.dart';
import '../application/shared/app_settings_store.dart';
import '../feature/shared/view_model/app_settings_view_model.dart';
import '../widget/business/icon/business_icon_scope.dart';
import 'business_icon_provider.dart';
import 'app_error_boundary.dart';
import 'provider.dart';
import 'router.dart';

class SmartFlowApp extends ConsumerStatefulWidget {
  const SmartFlowApp({super.key, this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  ConsumerState<SmartFlowApp> createState() => _SmartFlowAppState();
}

class _SmartFlowAppState extends ConsumerState<SmartFlowApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconCatalog = ref.watch(businessIconCatalogProvider);
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    return MaterialApp.router(
      title: 'SmartFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: widget.scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        ErrorWidget.builder = AppGlobalErrorHandler(
          scaffoldMessengerKey:
              widget.scaffoldMessengerKey ?? appScaffoldMessengerKey,
        ).buildErrorWidget;
        return BusinessIconScope(
          catalog: iconCatalog,
          accountStyle: settings.accountIconStyle,
          categoryStyle: settings.categoryIconStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: appRouter,
    );
  }
}
