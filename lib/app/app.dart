import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'notification_providers.dart';
import '../application/shared/notification/notification_delivery.dart';
import '../application/shared/task/foreground_task_runner.dart';
import '../application/intake/intake_recognition_api.dart';
import '../core/error/app_exception.dart';

// 框架委托的语言范围不同，只启用三者共同支持的语言。
final _supportedFrameworkLocales = List<Locale>.unmodifiable([
  const Locale('zh', 'CN'),
  ...kMaterialSupportedLanguages
      .where((languageCode) => languageCode != 'zh')
      .map(Locale.new)
      .where(
        (locale) =>
            GlobalWidgetsLocalizations.delegate.isSupported(locale) &&
            GlobalCupertinoLocalizations.delegate.isSupported(locale),
      ),
]);

class SmartFlowApp extends ConsumerStatefulWidget {
  const SmartFlowApp({super.key, this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  ConsumerState<SmartFlowApp> createState() => _SmartFlowAppState();
}

class _SmartFlowAppState extends ConsumerState<SmartFlowApp>
    with WidgetsBindingObserver {
  StreamSubscription<SharedPaymentImage>? _imageShares;
  StreamSubscription<NotificationOpen>? _notificationOpens;
  ForegroundTaskRunner? _foregroundTaskRunner;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(foregroundTaskRunnerProvider, (previous, next) {
        previous?.stop();
        _foregroundTaskRunner = next;
        // Dependency refreshes can arrive while providers are rebuilding.
        // Start only the current instance after that synchronous work finishes.
        scheduleMicrotask(() {
          if (mounted && identical(_foregroundTaskRunner, next)) {
            _applyTaskRunnerLifecycle();
          }
        });
      }, fireImmediately: true);
      unawaited(_applyLogRetentionSettings());
      unawaited(_listenForImageShares());
      unawaited(_listenForNotifications());
    });
  }

  void _applyTaskRunnerLifecycle() {
    if (_isForeground) {
      _foregroundTaskRunner?.start();
    } else {
      _foregroundTaskRunner?.stop();
    }
  }

  Future<void> _listenForNotifications() async {
    final delivery = ref.read(notificationDeliveryProvider);
    _notificationOpens = delivery.openedNotifications.listen(
      (notification) => unawaited(_openNotification(notification)),
    );
    try {
      await delivery.initialize();
      final notification = await delivery.initialNotification();
      if (mounted && notification != null) {
        await _openNotification(notification);
      }
    } on Exception catch (error, stackTrace) {
      Logger('app.notification').warning(
        'Cannot initialize notification navigation.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _openNotification(NotificationOpen notification) async {
    if (!mounted) return;
    final route = notification.route;
    final uri = Uri.tryParse(route);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !route.startsWith('/')) {
      return;
    }
    if (notification.registration case final registration?) {
      try {
        await ref
            .read(notificationInboxServiceProvider)
            .recordOpened(registration);
      } on Exception catch (error, stackTrace) {
        Logger('app.notification').warning(
          'Cannot mark opened notification as read.',
          error,
          stackTrace,
        );
      }
    }
    if (!mounted) return;
    if (appRouter.routeInformationProvider.value.uri.toString() != route) {
      unawaited(appRouter.push<void>(route));
    }
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
    _foregroundTaskRunner?.stop();
    unawaited(_notificationOpens?.cancel());
    unawaited(_imageShares?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      ref.invalidate(currentDateTimeProvider);
      ref.invalidate(notificationMessagesProvider);
      ref.invalidate(notificationPermissionProvider);
    }
    _applyTaskRunnerLifecycle();
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
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: _supportedFrameworkLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        for (final locale in locales ?? const <Locale>[]) {
          if (supportedLocales.any(
            (supported) => supported.languageCode == locale.languageCode,
          )) {
            // 保留系统的地区和文字体系，匹配简繁体等现成翻译。
            return locale;
          }
        }
        return supportedLocales.first;
      },
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
