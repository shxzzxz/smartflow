import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftAccountRepository', () {
    test(
      'throws BusinessException when saving a stale account snapshot',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final repository = DriftAccountRepository(database);
        await repository.create(_account('account-1'));

        final first = (await repository.findById('account-1'))!;
        final second = (await repository.findById('account-1'))!;
        first.name = 'First edit';
        second.name = 'Second edit';

        await repository.save(first);

        await expectLater(
          () => repository.save(second),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              AccountRepositoryErrorCode.concurrentUpdate.code,
            ),
          ),
        );
      },
    );

    test('delete removes the account row', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftAccountRepository(database);
      await repository.create(_account('account-1'));

      await repository.delete('account-1');

      expect(await repository.findById('account-1'), isNull);
    });
  });
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}
