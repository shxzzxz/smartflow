import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/transaction_view/business_activity/drift_business_activity_change_source.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = createTestDatabase();
    await database.customSelect('SELECT 1').get();
  });
  tearDown(() => database.close());

  test(
    'ledger-only queries ignore advance metadata and observe ledger content',
    () async {
      var notifications = 0;
      final subscription = DriftBusinessActivityChangeSource(
        database,
      ).watchChanges(_ledgerQuery()).listen((_) => notifications++);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(notifications, 1);

      await database
          .into(database.advanceCases)
          .insert(
            AdvanceCasesCompanion.insert(
              id: 'advance',
              scenario: AdvanceScenario.reimbursement,
              trackingMode: AdvanceTrackingMode.account,
              receivableAccountId: const Value('receivable'),
            ),
          );
      await pumpEventQueue();
      expect(notifications, 1);

      await database
          .into(database.counterparties)
          .insert(CounterpartiesCompanion.insert(id: 'merchant', name: '商户'));
      await pumpEventQueue();
      expect(notifications, 2);
    },
  );

  test(
    'buffers a committed multi-table change while the consumer is paused',
    () async {
      await DriftAccountRepository(database).create(
        Account(
          id: 'cash',
          name: '现金',
          type: AccountType.asset,
          subtype: AccountSubtype.fund,
          balance: const Money(minorUnits: 0),
        ),
      );
      await database
          .into(database.counterparties)
          .insert(CounterpartiesCompanion.insert(id: 'merchant', name: '商户'));
      var notifications = 0;
      final subscription = DriftBusinessActivityChangeSource(
        database,
      ).watchChanges(_ledgerQuery()).listen((_) => notifications++);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(notifications, 1);
      subscription.pause();

      await database.transaction(() async {
        await (database.update(database.accounts)
              ..where((row) => row.id.equals('cash')))
            .write(const AccountsCompanion(name: Value('备用现金')));
        await (database.update(database.counterparties)
              ..where((row) => row.id.equals('merchant')))
            .write(const CounterpartiesCompanion(name: Value('新商户')));
      });
      await pumpEventQueue();
      expect(notifications, 1);
      subscription.resume();
      await pumpEventQueue();
      expect(notifications, 2);
    },
  );
}

BusinessActivityPageQuery _ledgerQuery() => BusinessActivityPageQuery(
  occurredFrom: DateTime(2026, 11),
  occurredUntil: DateTime(2026, 12),
  activityTypes: const {ledgerTransactionGroupActivityType},
);
