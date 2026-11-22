import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';
import 'package:smartflow/application/credit/repayment_reminder/command/repayment_reminder_app_service.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/feature/profile/page/settings_page.dart';
import 'package:smartflow/feature/profile/page/header_appearance_page.dart';
import 'package:smartflow/feature/profile/page/navigation_appearance_page.dart';
import 'package:smartflow/feature/profile/page/theme_appearance_page.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import '../../../helper/fake_notification_delivery.dart';

class _Reminders extends Mock implements RepaymentReminderAppService {}

void main() {
  Future<void> open(
    WidgetTester tester,
    _InMemoryAppSettingsStore store, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/profile/settings',
      routes: [
        GoRoute(
          path: '/profile/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/profile/theme-appearance',
          builder: (context, state) => const ThemeAppearancePage(),
        ),
        GoRoute(
          path: '/profile/navigation-appearance',
          builder: (context, state) => const NavigationAppearancePage(),
        ),
        GoRoute(
          path: '/profile/header-appearance',
          builder: (context, state) => const HeaderAppearancePage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(store),
          notificationDeliveryProvider.overrideWithValue(
            FakeNotificationDelivery(),
          ),
          repaymentReminderAppServiceProvider.overrideWithValue(_reminders()),
          notificationInboxServiceProvider.overrideWith(
            (ref) => createMemoryNotificationInbox(),
          ),
          pullTaskSchedulerProvider.overrideWith((ref) {
            final scheduler = PullTaskScheduler(
              tasks: [ref.watch(notificationVisibilityTaskProvider)],
            );
            ref.onDispose(scheduler.dispose);
            return scheduler;
          }),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final appearance =
                ref.watch(appSettingsViewModelProvider).value?.appearance ??
                const AppAppearanceSettings();
            return MaterialApp.router(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark(appearance: appearance)
                  : AppTheme.light(appearance: appearance),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'notification settings use the project picker and save selected reminder time',
    (tester) async {
      final store = _InMemoryAppSettingsStore();
      await open(tester, store);
      await tester.ensureVisible(find.text('还款提醒时间'));
      expect(find.text('22:00'), findsOneWidget);
      await tester.tap(find.text('还款提醒时间'));
      await tester.pumpAndSettle();
      expect(find.byType(AppTimePickerDialog), findsOneWidget);
      final wheels = tester
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      final hour = wheels.first.controller! as FixedExtentScrollController;
      final minute = wheels.last.controller! as FixedExtentScrollController;
      hour.jumpToItem(hour.selectedItem - 1);
      minute.jumpToItem(minute.selectedItem + 30);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(
        (await store.read()).repaymentReminderTime,
        const NotificationTime(hour: 21, minute: 30),
      );
      expect((await store.read()).showAddTransactionFab, isTrue);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('还款提醒'));
      await tester.tap(find.text('还款提醒'));
      await tester.pumpAndSettle();
      expect((await store.read()).repaymentRemindersEnabled, isFalse);
    },
  );

  Future<void> chooseColor(
    WidgetTester tester,
    String label,
    String hex,
  ) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), hex);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('完成'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'grouped settings save operation and transaction display changes immediately',
    (tester) async {
      final store = _InMemoryAppSettingsStore();
      await open(tester, store);

      expect(find.text('设置'), findsOneWidget);
      for (final title in ['操作设置', '交易设置', '外观设置']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('操作设置')).dy,
        lessThan(tester.getTopLeft(find.text('交易设置')).dy),
      );
      expect(
        tester.getTopLeft(find.text('交易设置')).dy,
        lessThan(tester.getTopLeft(find.text('外观设置')).dy),
      );
      expect(find.text('首页下拉灵敏度'), findsOneWidget);
      expect(find.text('交易列表信息'), findsOneWidget);
      expect(find.text('收入颜色'), findsOneWidget);
      expect(find.text('支出颜色'), findsOneWidget);
      expect(find.text('主题外观'), findsOneWidget);
      expect(find.byIcon(RemixIcons.arrow_right_s_line), findsNWidgets(5));
      expect(find.text('保存'), findsNothing);

      await tester.tap(find.text('记账悬浮按钮'));
      await tester.pumpAndSettle();
      expect((await store.read()).showAddTransactionFab, isFalse);

      await tester.tap(find.text('首页下拉灵敏度'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('灵敏'));
      await tester.pumpAndSettle();
      expect(
        (await store.read()).pullToCreateSensitivity,
        PullToCreateSensitivity.sensitive,
      );

      await tester.ensureVisible(find.text('交易列表信息'));
      await tester.tap(find.text('交易列表信息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('紧凑'));
      await tester.pumpAndSettle();
      expect(
        (await store.read()).transactionListDisplayMode,
        TransactionListDisplayMode.compact,
      );

      final saved = await store.read();
      expect(saved.showAddTransactionFab, isFalse);
      expect(saved.bottomNavigationStyle, BottomNavigationStyle.classic);
      expect(saved.showBottomNavLabels, isTrue);
      expect(saved.pullToCreateSensitivity, PullToCreateSensitivity.sensitive);
      expect(
        saved.transactionListDisplayMode,
        TransactionListDisplayMode.compact,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in [
    ('导航栏外观', NavigationAppearancePage),
    ('顶部外观', HeaderAppearancePage),
  ]) {
    testWidgets('${entry.$1} entry opens its focused editor', (tester) async {
      await open(tester, _InMemoryAppSettingsStore());
      await tester.ensureVisible(find.text(entry.$1));
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(find.byType(entry.$2), findsOneWidget);
      expect(find.text('经典'), findsOneWidget);
      expect(find.text('玻璃'), findsOneWidget);
      expect(find.text('收入颜色'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('theme appearance entry opens the focused theme editor', (
    tester,
  ) async {
    await open(tester, _InMemoryAppSettingsStore());
    await tester.ensureVisible(find.text('主题外观'));
    await tester.tap(find.text('主题外观'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeAppearancePage), findsOneWidget);
    expect(find.text('主题外观'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('背景基色'), findsOneWidget);
    expect(find.text('背景风格'), findsOneWidget);
    expect(find.text('记账悬浮按钮'), findsNothing);
    expect(find.text('收入颜色'), findsNothing);
    expect(find.text('支出颜色'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'transaction colors save and update amount examples in $brightness mode',
      (tester) async {
        final store = _InMemoryAppSettingsStore();
        await open(tester, store, brightness: brightness);
        final settingsContext = tester.element(find.byType(SettingsPage));
        Color amountColor(MoneySemantic semantic) {
          final amount = find.byWidgetPredicate(
            (widget) => widget is MoneyText && widget.semantic == semantic,
          );
          return tester
              .widget<Text>(
                find.descendant(of: amount, matching: find.byType(Text)),
              )
              .style!
              .color!;
        }

        final before = await store.read();
        final incomeBefore = amountColor(MoneySemantic.income);
        final expenseBefore = amountColor(MoneySemantic.expense);
        expect(find.text('+99.99'), findsOneWidget);
        expect(find.text('-10.24'), findsOneWidget);
        expect(find.text('#00B85C'), findsNothing);
        expect(find.text('#FF2B2B'), findsNothing);

        await chooseColor(tester, '收入颜色', '9254DE');
        await chooseColor(tester, '支出颜色', '1976D2');
        final financeColors = Theme.of(
          settingsContext,
        ).extension<AppThemeExtension>()!;
        expect(amountColor(MoneySemantic.income), financeColors.income);
        expect(amountColor(MoneySemantic.expense), financeColors.expense);
        expect(amountColor(MoneySemantic.income), isNot(incomeBefore));
        expect(amountColor(MoneySemantic.expense), isNot(expenseBefore));
        expect(Theme.of(settingsContext).brightness, brightness);
        final saved = await store.read();
        expect(saved.appearance.incomeColor, 0xFF9254DE);
        expect(saved.appearance.expenseColor, 0xFF1976D2);
        expect(find.text('#9254DE'), findsNothing);
        expect(find.text('#1976D2'), findsNothing);
        expect(saved.appearance.primaryColor, before.appearance.primaryColor);
        expect(
          saved.appearance.backgroundSeedColor,
          before.appearance.backgroundSeedColor,
        );
        expect(saved.showAddTransactionFab, before.showAddTransactionFab);
        expect(store.writes, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets(
        'grouped settings fit a narrow $brightness screen at scale $scale',
        (tester) async {
          await open(
            tester,
            _InMemoryAppSettingsStore(),
            brightness: brightness,
            textScale: scale,
          );
          for (final label in [
            '记账悬浮按钮',
            '首页下拉灵敏度',
            '交易列表信息',
            '收入颜色',
            '支出颜色',
            '导航栏外观',
            '顶部外观',
            '主题外观',
            '还款提醒',
            '还款提醒时间',
            '系统通知权限',
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            expect(find.text(label).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}

class _InMemoryAppSettingsStore implements AppSettingsStore {
  AppSettings _settings = const AppSettings();
  int writes = 0;

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    writes++;
  }
}

_Reminders _reminders() {
  final service = _Reminders();
  when(() => service.synchronize(any())).thenAnswer((_) async {});
  return service;
}
