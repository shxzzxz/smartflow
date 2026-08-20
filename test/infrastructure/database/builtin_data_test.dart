import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/builtin_data.dart';
import 'package:smartflow/shared/account_group/initial_account_groups.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

import '../../helper/test_app_database.dart';

void main() {
  test('builtin data assigns receivable and payable profile groups', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'receivable',
            name: 'Receivable',
            accountType: AccountType.asset,
            accountSubtype: const Value(AccountSubtype.receivable),
            accountProfileKey: const Value('ledger.receivable'),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'payable',
            name: 'Payable',
            accountType: AccountType.liability,
            accountSubtype: const Value(AccountSubtype.payable),
            accountProfileKey: const Value('ledger.payable'),
          ),
        );
    await (database.update(database.appMetadata)..where(
      (row) => row.key.equals(builtinDataVersionKey),
    )).write(const AppMetadataCompanion(value: Value('9')));

    await ensureBuiltinData(database);
    await ensureBuiltinData(database);

    final receivable =
        await (database.select(database.accounts)
          ..where((row) => row.id.equals('receivable'))).getSingle();
    final payable =
        await (database.select(database.accounts)
          ..where((row) => row.id.equals('payable'))).getSingle();
    expect(
      receivable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.receivable),
    );
    expect(
      payable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.payable),
    );
  });
}
