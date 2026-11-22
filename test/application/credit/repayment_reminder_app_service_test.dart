import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/account/query/credit_account_queries.dart';
import 'package:smartflow/application/credit/account/query/credit_account_query_service.dart';
import 'package:smartflow/application/credit/account/query/credit_account_read_models.dart';
import 'package:smartflow/application/credit/repayment_reminder/command/repayment_reminder_app_service.dart';
import 'package:smartflow/application/credit/task/repayment_reminder_task.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';

import '../../helper/fake_notification_delivery.dart';

class _Accounts extends Mock implements CreditAccountQueryService {}

class _Settings implements AppSettingsStore {
  AppSettings settings = const AppSettings();
  @override
  Future<AppSettings> read() async => settings;
  @override
  Future<void> save(AppSettings value) async {
    settings = value;
  }
}

CreditDueCalendarItemReadModel _due(
  String id,
  DateTime date, {
  int pending = 100,
}) {
  return CreditDueCalendarItemReadModel.billItem(
    accountId: 'account-$id',
    billId: 'bill-$id',
    billItemId: id,
    dueDate: date,
    itemType: BillItemType.installment,
    status: BillItemStatus.partiallyPaid,
    principal: Money(minorUnits: pending),
    interest: const Money(minorUnits: 0),
    fee: const Money(minorUnits: 0),
    pendingTotal: Money(minorUnits: pending),
    isOverdue: false,
  );
}

void main() {
  final now = DateTime(2026, 11, 13, 21);
  setUpAll(() {
    registerFallbackValue(CreditDueCalendarQuery(from: now, until: now));
  });

  test(
    'default time is 22:00 and all accounts with the same due day merge',
    () async {
      final accounts = _Accounts();
      when(() => accounts.listDueCalendarItems(any())).thenAnswer(
        (_) async => [
          _due('first', DateTime(2026, 11, 14)),
          _due('second', DateTime(2026, 11, 14)),
          _due('zero', DateTime(2026, 11, 15), pending: 0),
          _due('past', DateTime(2026, 11, 12)),
          _due('later', DateTime(2026, 11, 16)),
        ],
      );
      final delivery = FakeNotificationDelivery();
      final service = RepaymentReminderAppService(
        settings: _Settings(),
        accounts: accounts,
        notifications: NotificationSyncService(
          delivery: delivery,
          registry: MemoryNotificationRegistry(),
          inbox: createMemoryNotificationInbox(),
        ),
      );
      expect(
        (await RepaymentReminderTask(service).run(now)).outcome,
        AppTaskOutcome.completed,
      );
      expect(delivery.scheduled, hasLength(2));
      expect(
        delivery.scheduled.first.$2.scheduledAt,
        DateTime(2026, 11, 13, 22),
      );
      expect(delivery.scheduled.first.$2.expiresAt, DateTime(2026, 11, 15));
      expect(
        delivery.scheduled.first.$2.route,
        '/calendar/bills/day?date=2026-11-14',
      );
      final query =
          verify(
                () => accounts.listDueCalendarItems(captureAny()),
              ).captured.single
              as CreditDueCalendarQuery;
      expect(query.from, DateTime(2026, 11, 13));
      expect(delivery.shown, isEmpty);
    },
  );

  test(
    'time changes replace plans and disabling cancels without querying bills',
    () async {
      final accounts = _Accounts();
      when(
        () => accounts.listDueCalendarItems(any()),
      ).thenAnswer((_) async => [_due('one', DateTime(2026, 11, 14))]);
      final settings = _Settings();
      final delivery = FakeNotificationDelivery();
      final service = RepaymentReminderAppService(
        settings: settings,
        accounts: accounts,
        notifications: NotificationSyncService(
          delivery: delivery,
          registry: MemoryNotificationRegistry(),
          inbox: createMemoryNotificationInbox(),
        ),
      );
      await service.synchronize(now);
      final id = delivery.scheduled.single.$1;
      settings.settings = settings.settings.copyWith(
        repaymentReminderTime: const NotificationTime(hour: 23, minute: 15),
      );
      await service.synchronize(now);
      expect(delivery.scheduled.last.$1, id);
      expect(
        delivery.scheduled.last.$2.scheduledAt,
        DateTime(2026, 11, 13, 23, 15),
      );
      clearInteractions(accounts);
      settings.settings = settings.settings.copyWith(
        repaymentRemindersEnabled: false,
      );
      await service.synchronize(now);
      verifyNever(() => accounts.listDueCalendarItems(any()));
      expect(delivery.cancelled, contains(id));
      expect(delivery.pending, isEmpty);
    },
  );
}
