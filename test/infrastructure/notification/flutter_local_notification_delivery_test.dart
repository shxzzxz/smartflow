import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/infrastructure/notification/flutter_local_notification_delivery.dart';
import 'package:timezone/timezone.dart' as timezone;

class _Plugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _Android extends Mock implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final route = '/calendar/bills/day?date=2026-11-14';
  final response = NotificationResponse(
    notificationResponseType: NotificationResponseType.selectedNotification,
    payload: route,
  );

  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
    );
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(timezone.TZDateTime(timezone.UTC, 2026));
    registerFallbackValue((NotificationResponse response) {});
  });

  test(
    'adapter preserves local instants through UTC transport and routes cold and live taps',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final plugin = _Plugin();
      final android = _Android();
      when(
        () => plugin.initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.areNotificationsEnabled(),
      ).thenAnswer((_) async => true);
      when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
        (_) async =>
            NotificationAppLaunchDetails(true, notificationResponse: response),
      );
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
      when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
      final delivery = FlutterLocalNotificationDelivery(plugin: plugin);
      addTearDown(delivery.dispose);
      await delivery.initialize();
      expect(await delivery.isPermissionGranted(), isTrue);
      final plan = NotificationPlan(
        key: '2026-11-14',
        scheduledAt: DateTime.utc(2026, 11, 13, 14),
        expiresAt: DateTime.utc(2026, 11, 14, 16),
        title: '还款提醒',
        body: '待还提醒',
        route: route,
      );
      final registration = RegisteredNotification(
        scope: 'repayment',
        id: 42,
        plan: plan,
      );
      final payload = jsonEncode(registration.toJson());
      final encodedResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      );
      when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
        (_) async => NotificationAppLaunchDetails(
          true,
          notificationResponse: encodedResponse,
        ),
      );
      when(() => plugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          PendingNotificationRequest(42, plan.title, plan.body, payload),
          PendingNotificationRequest(7, 'other', 'other', 'opaque'),
        ],
      );
      await delivery.schedule(registration);
      final pending = await delivery.pendingNotifications();
      expect(pending.first.registration?.identity, registration.identity);
      expect(pending.last.id, 7);
      expect(pending.last.registration, isNull);
      final scheduled =
          verify(
                () => plugin.zonedSchedule(
                  id: 42,
                  title: plan.title,
                  body: plan.body,
                  scheduledDate: captureAny(named: 'scheduledDate'),
                  notificationDetails: any(named: 'notificationDetails'),
                  androidScheduleMode:
                      AndroidScheduleMode.inexactAllowWhileIdle,
                  payload: payload,
                ),
              ).captured.single
              as timezone.TZDateTime;
      expect(scheduled.timeZoneOffset, Duration.zero);
      expect(scheduled.isAtSameMomentAs(plan.scheduledAt), isTrue);
      expect(scheduled.hour, 14);
      expect(scheduled.day, 13);
      final initial = await delivery.initialNotification();
      expect(initial?.route, route);
      expect(initial?.registration?.identity, registration.identity);
      final callback =
          verify(
                () => plugin.initialize(
                  settings: any(named: 'settings'),
                  onDidReceiveNotificationResponse: captureAny(
                    named: 'onDidReceiveNotificationResponse',
                  ),
                ),
              ).captured.single
              as DidReceiveNotificationResponseCallback;
      final opened = delivery.openedNotifications.first;
      callback(encodedResponse);
      final live = await opened;
      expect(live.route, route);
      expect(live.registration?.identity, registration.identity);
      await delivery.cancel(42);
      verify(() => plugin.cancel(id: 42)).called(1);
      verifyNever(() => android.requestExactAlarmsPermission());
    },
  );
}
