// Native verification without opening the financial database.
// fvm flutter build apk --debug --target test_driver/notification_smoke.dart
// The debug build detects this target and applies the isolated package suffix.
// The isolated package is com.shxzz.smartflow.notification_smoke.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';
import 'package:smartflow/infrastructure/notification/flutter_local_notification_delivery.dart';

import '../test/helper/fake_notification_delivery.dart';

const _route = '/calendar/bills/day?date=2026-11-14';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Center(child: Text('系统通知验证'))),
      ),
    ),
  );
  unawaited(_verify());
}

Future<void> _verify() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final delivery = FlutterLocalNotificationDelivery(plugin: plugin);
  delivery.openedNotifications.listen((notification) {
    final route = notification.route;
    debugPrint(route == _route ? 'SMOKE_LIVE_ROUTE_OK' : 'SMOKE_ROUTE_FAILURE');
  });
  try {
    await delivery.initialize();
    final launchRoute = (await delivery.initialNotification())?.route;
    if (launchRoute != null) {
      debugPrint(
        launchRoute == _route ? 'SMOKE_COLD_ROUTE_OK' : 'SMOKE_ROUTE_FAILURE',
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      final id = launch?.notificationResponse?.id;
      if (id != null) await delivery.cancel(id);
      return;
    }
    if (!await delivery.isPermissionGranted()) {
      debugPrint('SMOKE_NEEDS_PERMISSION');
      return;
    }
    final now = DateTime.now();
    final registry = MemoryNotificationRegistry();
    final service = NotificationSyncService(
      delivery: delivery,
      registry: registry,
      inbox: createMemoryNotificationInbox(),
      clock: DateTime.now,
    );
    final immediate = NotificationPlan(
      key: 'probe-now',
      scheduledAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(hours: 2)),
      title: '通知验证',
      body: '用于验证本地通知和点击跳转。',
      route: _route,
    );
    final future = NotificationPlan(
      key: 'probe-future',
      scheduledAt: now.add(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 2)),
      title: '排程验证',
      body: '此排程将在验证结束后取消。',
      route: _route,
    );
    await service.synchronize(
      scope: 'smoke',
      plans: [immediate, future],
      now: now,
    );
    final activeId = registry.state.entries
        .firstWhere((entry) => entry.plan.key == immediate.key)
        .id;
    final active = await plugin.getActiveNotifications();
    if (!active.any((entry) => entry.id == activeId)) {
      throw StateError('Immediate notification is not active.');
    }
    final pending = await delivery.pendingNotifications();
    if (!pending.any((entry) => entry.registration?.plan.key == future.key)) {
      throw StateError('Future notification is not pending.');
    }
    // Simulate a lost local registration after the OS accepted the schedule.
    registry.state = NotificationRegistryState();
    await service.synchronize(scope: 'smoke', plans: [], now: DateTime.now());
    if ((await delivery.pendingNotifications()).any(
      (entry) => entry.registration?.scope == 'smoke',
    )) {
      throw StateError('Recovered schedule was not cancelled.');
    }
    debugPrint('SMOKE_ACTIVE_ID:$activeId');
    debugPrint('SMOKE_POST_AND_CANCEL_OK');
  } catch (error, stackTrace) {
    debugPrint('SMOKE_FAILURE:${error.runtimeType}');
    debugPrintStack(stackTrace: stackTrace);
  }
}
