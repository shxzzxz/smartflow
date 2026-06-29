import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test('schema v14 creates credit repayment tables', () async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: _createV13Database),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);

    await database
        .into(database.repayments)
        .insert(
          RepaymentsCompanion.insert(
            id: 'repayment-1',
            repaymentType: 'BILL',
            targetType: 'BILL',
            targetId: 'bill-1',
          ),
        );
    await database
        .into(database.repaymentItems)
        .insert(
          RepaymentItemsCompanion.insert(
            id: 'item-1',
            repaymentId: 'repayment-1',
            billItemId: const Value('bill-item-1'),
            allocatedPrincipalMinor: 1000,
            allocatedInterestMinor: 0,
            allocatedFeeMinor: 0,
            allocatedDiscountMinor: 0,
          ),
        );

    expect(await database.select(database.repayments).get(), hasLength(1));
    expect(await database.select(database.repaymentItems).get(), hasLength(1));
  });

  test(
    'schema v15 adds source repayment id to installment contracts',
    () async {
      final database = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(setup: _createV14InstallmentDatabase),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(database.close);

      final rows = await database.select(database.installmentContracts).get();
      expect(rows.single.sourceRepaymentId, isNull);

      await (database.update(database.installmentContracts)
        ..where((row) => row.id.equals('contract-1'))).write(
        const InstallmentContractsCompanion(
          sourceRepaymentId: Value('repayment-1'),
        ),
      );

      final updated =
          await database.select(database.installmentContracts).get();
      expect(updated.single.sourceRepaymentId, 'repayment-1');
    },
  );

  test('schema v16 drops legacy installment repayments table', () async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: _createV15InstallmentRepaymentsDatabase),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);

    final rows =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'installment_repayments'",
            )
            .get();

    expect(rows, isEmpty);
  });
}

void _createV13Database(dynamic database) {
  database.execute('''
    CREATE TABLE app_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO app_metadata (key, value, updated_at) "
    "VALUES ('builtin_data_version', '8', 0)",
  );
  database.execute('PRAGMA user_version = 13');
}

void _createV14InstallmentDatabase(dynamic database) {
  database.execute('''
    CREATE TABLE app_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO app_metadata (key, value, updated_at) "
    "VALUES ('builtin_data_version', '8', 0)",
  );
  database.execute('''
    CREATE TABLE installment_contracts (
      id TEXT NOT NULL PRIMARY KEY,
      liability_account_id TEXT NOT NULL,
      source_type TEXT NOT NULL,
      disbursement_account_id TEXT NULL,
      disbursement_transaction_id TEXT NULL,
      principal_minor INTEGER NOT NULL,
      total_periods INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      first_repayment_date INTEGER NOT NULL,
      last_repayment_date INTEGER NOT NULL,
      repayment_method TEXT NOT NULL,
      interest_rate_period TEXT NULL,
      interest_rate_ppm INTEGER NULL,
      interest_accrual_method TEXT NOT NULL DEFAULT 'daily',
      total_fee_minor INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      note TEXT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO installment_contracts ("
    "id, liability_account_id, source_type, principal_minor, total_periods, "
    "start_date, first_repayment_date, last_repayment_date, repayment_method, "
    "interest_accrual_method, status, created_at, updated_at"
    ") VALUES ("
    "'contract-1', 'credit-1', 'billConversion', 6000, 2, "
    "1782345600, 1784937600, 1787616000, 'equalPrincipal', "
    "'daily', 'active', 1782345600, 1782345600"
    ")",
  );
  database.execute('PRAGMA user_version = 14');
}

void _createV15InstallmentRepaymentsDatabase(dynamic database) {
  database.execute('''
    CREATE TABLE app_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO app_metadata (key, value, updated_at) "
    "VALUES ('builtin_data_version', '8', 0)",
  );
  database.execute('''
    CREATE TABLE installment_repayments (
      id TEXT NOT NULL PRIMARY KEY,
      contract_id TEXT NOT NULL,
      repayment_type TEXT NOT NULL,
      schedule_id TEXT NULL,
      transaction_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    'CREATE UNIQUE INDEX installment_repayments_contract_schedule_unique '
    'ON installment_repayments (contract_id, schedule_id) '
    'WHERE schedule_id IS NOT NULL',
  );
  database.execute(
    'CREATE INDEX installment_repayments_transaction_idx '
    'ON installment_repayments (transaction_id)',
  );
  database.execute('PRAGMA user_version = 15');
}
