import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../design_system/theme/app_theme.dart';
import '../application/shared/app_settings_store.dart';
import '../feature/shared/view_model/app_settings_view_model.dart';
import '../feature/shared/provider/current_date_time_provider.dart';
import '../widget/business/icon/business_icon_scope.dart';
import 'business_icon_provider.dart';
import 'app_error_boundary.dart';
import 'provider.dart';
import 'router.dart';
import 'capture_intake_provider.dart';
import 'capture_intake_navigation.dart';
import '../application/intake/intake_recognition_api.dart';
import '../core/error/app_exception.dart';

class SmartFlowApp extends ConsumerStatefulWidget {
  const SmartFlowApp({super.key, this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  ConsumerState<SmartFlowApp> createState() => _SmartFlowAppState();
}

class _SmartFlowAppState extends ConsumerState<SmartFlowApp>
    with WidgetsBindingObserver {
  StreamSubscription<SharedPaymentImage>? _imageShares;
  Timer? _dailyTaskTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
      _scheduleNextDay();
      unawaited(_applyLogRetentionSettings());
      unawaited(_listenForImageShares());
    });
  }

  Future<void> _listenForImageShares() async {
    final source = ref.read(sharedPaymentImageSourceProvider);
    _imageShares = source.shares.listen(_openSharedImage);
    final logger = Logger('app.capture');
    try {
      final image = await source.takeInitialShare();
      if (mounted && image != null) _openSharedImage(image);
    } on AppException catch (error, stackTrace) {
      logger.warning(
        'Cannot receive shared image [${error.code}].',
        error.cause ?? error,
        error.stackTrace ?? stackTrace,
      );
    } on Exception catch (error, stackTrace) {
      logger.warning('Cannot receive shared image.', error, stackTrace);
    }
  }

  void _openSharedImage(SharedPaymentImage image) {
    if (!mounted) return;
    openSharedPaymentImage(appRouter, image);
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
    _dailyTaskTimer?.cancel();
    unawaited(_imageShares?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(currentDateTimeProvider);
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
      _scheduleNextDay();
    } else {
      _dailyTaskTimer?.cancel();
    }
  }

  void _scheduleNextDay() {
    _dailyTaskTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dailyTaskTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      ref.invalidate(currentDateTimeProvider);
      unawaited(ref.read(pullTaskSchedulerProvider).trigger());
      _scheduleNextDay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconRegistry = ref.watch(businessIconRegistryProvider);
    final appearance = ref.watch(
      appSettingsViewModelProvider.select(
        (settings) =>
            settings.value?.appearance ?? const AppAppearanceSettings(),
      ),
    );
    return MaterialApp.router(
      title: 'SmartFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: widget.scaffoldMessengerKey,
      theme: AppTheme.light(appearance: appearance),
      darkTheme: AppTheme.dark(appearance: appearance),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        ErrorWidget.builder = AppGlobalErrorHandler(
          scaffoldMessengerKey:
              widget.scaffoldMessengerKey ?? appScaffoldMessengerKey,
        ).buildErrorWidget;
        return BusinessIconScope(
          registry: iconRegistry,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: appRouter,
    );
  }
}
