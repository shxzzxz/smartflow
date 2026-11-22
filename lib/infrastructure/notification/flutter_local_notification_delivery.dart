import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../../application/shared/notification/notification_delivery.dart';
import '../../application/shared/notification/notification_registry.dart';

class FlutterLocalNotificationDelivery implements NotificationDelivery {
  FlutterLocalNotificationDelivery({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _openedNotifications = StreamController<NotificationOpen>.broadcast();
  Future<void>? _initialization;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'smartflow_reminders',
      '提醒',
      channelDescription: 'SmartFlow 的还款等事项提醒',
      icon: 'ic_stat_notification',
      category: AndroidNotificationCategory.reminder,
      onlyAlertOnce: true,
    ),
  );

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<NotificationOpen> get openedNotifications =>
      _openedNotifications.stream;

  Future<void> _ensureInitialized() async {
    if (!isSupported) return;
    final future = _initialization ??= _initializePlugin();
    try {
      await future;
    } catch (_) {
      if (identical(_initialization, future)) _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    final result = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final notification = _open(response.payload);
        if (notification != null && !_openedNotifications.isClosed) {
          _openedNotifications.add(notification);
        }
      },
    );
    if (result != true) {
      throw Exception('Cannot initialize local notifications.');
    }
  }

  @override
  Future<void> initialize() async {
    if (!isSupported) return;
    await _ensureInitialized();
  }

  @override
  Future<NotificationOpen?> initialNotification() async {
    if (!isSupported) return null;
    await _ensureInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? _open(details?.notificationResponse?.payload)
        : null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    if (!isSupported) return const [];
    await _ensureInitialized();
    return (await _plugin.pendingNotificationRequests()).map((request) {
      final registration = _decode(request.payload);
      return PendingNotification(
        id: request.id,
        registration: registration?.id == request.id ? registration : null,
      );
    }).toList();
  }

  @override
  Future<void> schedule(RegisteredNotification notification) async {
    if (!isSupported) return;
    await _ensureInitialized();
    final plan = notification.plan;
    await _plugin.zonedSchedule(
      id: notification.id,
      title: plan.title,
      body: plan.body,
      // Discovery already computes the exact local-date instant. UTC transport
      // preserves it without requiring device IANA aliases or a timezone DB.
      scheduledDate: timezone.TZDateTime.from(plan.scheduledAt, timezone.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(notification.toJson()),
    );
  }

  @override
  Future<void> show(RegisteredNotification notification) async {
    if (!isSupported) return;
    await _ensureInitialized();
    final plan = notification.plan;
    await _plugin.show(
      id: notification.id,
      title: plan.title,
      body: plan.body,
      notificationDetails: _details,
      payload: jsonEncode(notification.toJson()),
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  Future<void> dispose() => _openedNotifications.close();

  RegisteredNotification? _decode(String? payload) {
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload);
      return json is Map<String, dynamic>
          ? RegisteredNotification.fromJson(json)
          : null;
    } on FormatException {
      return null;
    }
  }

  NotificationOpen? _open(String? payload) {
    final registration = _decode(payload);
    if (registration != null) {
      return NotificationOpen(
        route: registration.plan.route,
        registration: registration,
      );
    }
    return payload?.startsWith('/') == true
        ? NotificationOpen(route: payload!)
        : null;
  }
}
