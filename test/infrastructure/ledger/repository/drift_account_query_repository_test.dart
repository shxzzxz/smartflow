import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_query_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'excludes archived accounts from lists but keeps them readable by id',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final commandRepository = DriftAccountRepository(database);
      final queryRepository = DriftAccountQueryRepository(database);
      final active = _account('active');
      final archived = _account('archived');
      await commandRepository.create(active);
      await commandRepository.create(archived);
      archived.archive(DateTime(2026, 7, 16));
      await commandRepository.save(archived);

      final accounts =
          await queryRepository.watchAccounts({AccountType.asset}).first;
      final archivedById = await queryRepository.findAccountById(archived.id);

      expect(accounts.map((account) => account.id), ['active']);
      expect(archivedById?.isArchived, true);
    },
  );
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: Money.zero(),
  );
}
