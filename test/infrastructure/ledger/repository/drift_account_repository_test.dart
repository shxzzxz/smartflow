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

    test(
      'findArchivedMountsOf returns only archived children of given ids',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final repository = DriftAccountRepository(database);
        await repository.create(
          _account('root', type: AccountType.expense),
        );
        await repository.create(
          _account('active-child', type: AccountType.expense, parentId: 'root'),
        );
        // create 不落 archivedAt（新账户不会生而归档），归档态通过 save 写入。
        final mount = _account('mount', type: AccountType.expense);
        await repository.create(mount);
        mount
          ..parentId = 'root'
          ..archivedAt = DateTime(2026);
        await repository.save(mount);
        final otherMount = _account('other-mount', type: AccountType.expense);
        await repository.create(otherMount);
        otherMount
          ..parentId = 'elsewhere'
          ..archivedAt = DateTime(2026);
        await repository.save(otherMount);

        final mounts = await repository.findArchivedMountsOf({'root'});

        expect(mounts.map((account) => account.id), ['mount']);
        expect(
          (await repository.findChildrenOf('root')).map((a) => a.id),
          ['active-child'],
        );
      },
    );
  });
}

Account _account(
  String id, {
  AccountType type = AccountType.asset,
  String? parentId,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
  );
}
