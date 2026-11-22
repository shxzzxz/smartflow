import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/notification_center_page.dart';
import 'package:smartflow/feature/profile/page/profile_page.dart';

import '../../../helper/fake_notification_delivery.dart';

NotificationPlan messagePlan({String key = '2026-11-23', int hour = 10}) =>
    NotificationPlan(
      key: key,
      scheduledAt: DateTime(2026, 11, 22, hour),
      expiresAt: DateTime(2026, 11, 24),
      title: '还款提醒',
      body: '2026年11月23日有待还账单，点击查看。',
      route: '/calendar/bills/day?date=$key',
    );

void main() {
  const updateChannel = MethodChannel('com.shxzz.smartflow/app_update');
  late MemoryNotificationInboxStore store;
  late NotificationInboxService inbox;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 22, 9, 59);
    store = MemoryNotificationInboxStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          if (call.method == 'getVersionInfo') {
            return {'versionName': '0.9.5', 'buildNumber': 1};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, null);
    await store.dispose();
  });

  Future<GoRouter> open(
    WidgetTester tester, {
    String initialLocation = '/profile',
    bool largeText = false,
  }) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/profile/notifications',
          builder: (context, state) => const NotificationCenterPage(),
        ),
        GoRoute(
          path: '/calendar/bills/day',
          builder: (context, state) => const Scaffold(body: Text('当日待还账单')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationInboxServiceProvider.overrideWithValue(inbox)],
        child: MaterialApp.router(
          theme: largeText ? AppTheme.dark() : AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(largeText ? 1.6 : 1)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    return router;
  }

  testWidgets(
    'profile header enters inbox, future messages stay hidden, and opening marks read',
    (tester) async {
      // Keep the serialized flow's initial future inside the test clock zone.
      inbox = NotificationInboxService(store: store, clock: () => now);
      await inbox.synchronize(
        scope: 'repayment',
        plans: [messagePlan()],
        now: now,
      );
      final router = await open(tester);
      final entry = find.byKey(const ValueKey('profile-notifications'));
      Badge badge() => tester.widget<Badge>(
        find.descendant(of: entry, matching: find.byType(Badge)),
      );
      expect(badge().isLabelVisible, isFalse);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('通知中心'), findsOneWidget);
      expect(find.text('暂无通知'), findsOneWidget);
      expect(find.text('还款提醒'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      now = DateTime(2026, 11, 22, 10);
      // Opening the center refreshes a cached, previously hidden message even
      // when the next automatic check has not yet fired.
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('还款提醒'), findsOneWidget);
      expect(find.text('1 条未读'), findsOneWidget);
      await tester.tap(find.text('还款提醒'));
      await tester.pumpAndSettle();
      expect(find.text('当日待还账单'), findsOneWidget);
      expect(store.messages.single.isRead, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read all updates visible messages and preserves future unread state at large text',
    (tester) async {
      // Keep the serialized flow's initial future inside the test clock zone.
      inbox = NotificationInboxService(store: store, clock: () => now);
      await inbox.synchronize(
        scope: 'repayment',
        plans: [
          messagePlan(),
          messagePlan(key: 'future', hour: 12),
        ],
        now: now,
      );
      now = DateTime(2026, 11, 22, 10);
      await open(
        tester,
        initialLocation: '/profile/notifications',
        largeText: true,
      );
      expect(find.text('还款提醒'), findsOneWidget);
      expect(find.text('1 条未读'), findsOneWidget);
      await tester.tap(find.text('全部已读'));
      await tester.pumpAndSettle();
      expect(store.messages.first.isRead, isTrue);
      expect(store.messages.last.isRead, isFalse);
      expect(find.text('1 条未读'), findsNothing);
      final badges = tester.widgetList<Badge>(find.byType(Badge));
      expect(badges.every((badge) => !badge.isLabelVisible), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
