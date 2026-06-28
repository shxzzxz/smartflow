import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test('schema v12 backfills credit liability account extensions', () async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: _createV11Database),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);

    final rows = await database.select(database.creditLiabilityAccounts).get();

    final byAccountId = {for (final row in rows) row.accountId: row};
    expect(
      byAccountId['credit-valid']!.kind,
      CreditLiabilityAccountKind.credit,
    );
    expect(
      byAccountId['credit-valid']!.id,
      'credit-liability-account:credit-valid',
    );
    expect(byAccountId['credit-valid']!.creditLimitMinor, 100000);
    expect(byAccountId['credit-valid']!.billingDay, 5);
    expect(byAccountId['credit-valid']!.repaymentDay, 25);
    expect(byAccountId['credit-valid']!.billingStartPeriod, 202605);
    expect(byAccountId['credit-invalid']!.billingDay, 1);
    expect(byAccountId['credit-invalid']!.repaymentDay, 28);
    expect(byAccountId['loan']!.kind, CreditLiabilityAccountKind.loan);
    expect(byAccountId['loan']!.billingDay, isNull);
    expect(byAccountId['loan']!.repaymentDay, isNull);
    expect(byAccountId['loan']!.billingStartPeriod, isNull);
  });
}

void _createV11Database(dynamic database) {
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
    CREATE TABLE accounts (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      account_type TEXT NOT NULL,
      account_subtype TEXT NULL,
      account_profile_key TEXT NULL,
      parent_id TEXT NULL,
      balance_minor INTEGER NOT NULL DEFAULT 0,
      icon_key TEXT NULL,
      note TEXT NULL,
      credit_limit_minor INTEGER NULL,
      billing_day INTEGER NULL,
      repayment_day INTEGER NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_hidden INTEGER NOT NULL DEFAULT 0,
      archived_at INTEGER NULL,
      system_key TEXT NULL,
      source TEXT NOT NULL DEFAULT 'user',
      version INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO accounts ("
    "id, name, account_type, account_profile_key, balance_minor, "
    "credit_limit_minor, billing_day, repayment_day, created_at, updated_at"
    ") VALUES "
    "('credit-valid', 'Credit Valid', 'liability', 'credit.credit', 0, "
    "100000, 5, 25, 1777593600, 1777593600), "
    "('credit-invalid', 'Credit Invalid', 'liability', 'credit.credit', 0, "
    "NULL, 31, NULL, 1780272000, 1780272000), "
    "('loan', 'Loan', 'liability', 'credit.loan', 0, "
    "300000, 10, 20, 1780272000, 1780272000)",
  );
  database.execute('PRAGMA user_version = 11');
}
