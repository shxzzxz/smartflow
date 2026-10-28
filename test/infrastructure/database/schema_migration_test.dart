import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v49.dart' as v49;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v49 to v50 without losing account data', () async {
    await verifier.testWithDataIntegrity<v49.DatabaseAtV49, AppDatabase>(
      createOld: v49.DatabaseAtV49.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          '''
          INSERT INTO accounts (
            id,
            name,
            account_type,
            account_subtype,
            account_profile_key,
            balance_minor,
            credit_limit_minor,
            billing_day,
            repayment_day
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            'credit',
            '信用卡',
            'liability',
            'payable',
            'credit.credit',
            1200,
            100000,
            5,
            25,
          ],
        );
        batch.customStatement(
          '''
          INSERT INTO credit_liability_accounts (
            id,
            account_id,
            kind,
            credit_limit_minor,
            billing_day,
            repayment_day,
            billing_day_to_next
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          ['credit-extension', 'credit', 'credit', 100000, 5, 25, 1],
        );
      },
      validateItems: (db) async {
        final accountQuery = db.select(db.accounts)
          ..where((row) => row.id.equals('credit'));
        final account = await accountQuery.getSingle();
        expect(account.name, '信用卡');
        expect(account.balanceMinor, 1200);
        expect(account.accountProfileKey, 'credit.credit');

        final extensionQuery = db.select(db.creditLiabilityAccounts)
          ..where((row) => row.accountId.equals('credit'));
        final extension = await extensionQuery.getSingle();
        expect(extension.creditLimitMinor, 100000);
        expect(extension.billingDay, 5);
        expect(extension.repaymentDay, 25);

        final columnNames =
            (await db.customSelect('PRAGMA table_info(accounts)').get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(columnNames, isNot(contains('credit_limit_minor')));
        expect(columnNames, isNot(contains('billing_day')));
        expect(columnNames, isNot(contains('repayment_day')));
      },
      oldVersion: 49,
      newVersion: 50,
    );
  });
}
