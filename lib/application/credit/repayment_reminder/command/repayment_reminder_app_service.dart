import '../../../shared/app_settings_store.dart';
import '../../../shared/notification/notification_plan.dart';
import '../../../shared/notification/notification_sync_service.dart';
import '../../account/query/credit_account_queries.dart';
import '../../account/query/credit_account_query_service.dart';

/// Discovers existing bill obligations without coupling credit write use cases
/// to notification delivery. Concurrent discovery runs are serialized here.
class RepaymentReminderAppService {
  RepaymentReminderAppService({
    required AppSettingsStore settings,
    required CreditAccountQueryService accounts,
    required NotificationSyncService notifications,
  }) : _settings = settings,
       _accounts = accounts,
       _notifications = notifications;

  static const scope = 'credit.repayment_reminder';
  static const planningDays = 90;

  final AppSettingsStore _settings;
  final CreditAccountQueryService _accounts;
  final NotificationSyncService _notifications;
  Future<void> _pending = Future<void>.value();

  Future<void> synchronize(DateTime now) {
    final operation = _pending.then((_) => _synchronize(now));
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<void> _synchronize(DateTime now) async {
    final settings = await _settings.read();
    final today = DateTime(now.year, now.month, now.day);
    final plans = <NotificationPlan>[];
    if (settings.repaymentRemindersEnabled) {
      final items = await _accounts.listDueCalendarItems(
        CreditDueCalendarQuery(
          from: today,
          until: DateTime(
            today.year,
            today.month,
            today.day + planningDays + 1,
          ),
        ),
      );
      final dates = {
        for (final item in items)
          if (item.pendingTotal.minorUnits > 0)
            DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day),
      }.toList()..sort();
      for (final date in dates) {
        // Defend the expiry boundary even when a query implementation changes.
        if (date.isBefore(today)) continue;
        final key =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        plans.add(
          NotificationPlan(
            key: key,
            scheduledAt: DateTime(
              date.year,
              date.month,
              date.day - 1,
              settings.repaymentReminderTime.hour,
              settings.repaymentReminderTime.minute,
            ),
            expiresAt: DateTime(date.year, date.month, date.day + 1),
            title: '还款提醒',
            body: '${date.year}年${date.month}月${date.day}日有待还账单，点击查看。',
            route: '/calendar/bills/day?date=$key',
          ),
        );
      }
    }
    await _notifications.synchronize(scope: scope, plans: plans, now: now);
  }
}
