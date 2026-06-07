import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

import '../../../helper/sequential_id_generator.dart';

void main() {
  group('CategoryAppService', () {
    test(
      'rejects moving a root category with children under another parent',
      () async {
        final root = _category('root');
        final child = _category('child', parentId: root.id);
        final parent = _category('parent');
        final service = CategoryAppServiceImpl(
          repository: _FakeAccountRepository([root, child, parent]),
          idGenerator: SequentialIdGenerator(),
        );

        await expectLater(
          () => service.editCategory(
            EditCategoryCommand(
              id: root.id,
              name: root.name,
              parentId: Patch.set(parent.id),
            ),
          ),
          throwsA(
            isA<BusinessException>()
                .having(
                  (exception) => exception.code,
                  'code',
                  LedgerErrorCode.categoryInvalidParent.code,
                )
                .having(
                  (exception) => exception.message,
                  'message',
                  '已有子分类，不能设为子分类。',
                ),
          ),
        );
      },
    );
  });
}

Account _category(String id, {String? parentId}) {
  return Account(
    id: id,
    name: id,
    type: AccountType.expense,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  @override
  Future<void> create(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<Account?> findById(String id) async => _accounts[id];

  @override
  Future<List<Account>> findByIds(Set<String> ids) async {
    return [
      for (final id in ids)
        if (_accounts[id] != null) _accounts[id]!,
    ];
  }

  @override
  Future<List<Account>> findChildrenOf(String parentId) async {
    return [
      for (final account in _accounts.values)
        if (account.parentId == parentId && !account.isArchived) account,
    ];
  }

  @override
  Future<void> save(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    for (final account in accounts) {
      _accounts[account.id] = account;
    }
  }
}
