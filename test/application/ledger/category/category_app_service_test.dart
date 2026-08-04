import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
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
        final service = _service(accounts: [root, child, parent]);

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

  group('CategoryAppService.previewCategoryDeletion', () {
    test('rejects a system category even when it has no references', () async {
      final category = _category('system-fee', systemKey: SystemKey.feeExpense);
      final service = _service(accounts: [category]);

      await expectLater(
        () => service.previewCategoryDeletion(category.id),
        throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
      );
    });

    test('reports child count and transaction reference count', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final service = _service(
        accounts: [root, child],
        entryCounts: {root.id: 3},
        reimbursementRefCounts: {root.id: 2},
      );

      final preview = await service.previewCategoryDeletion(root.id);

      expect(preview.childCount, 1);
      expect(preview.transactionRefCount, 5);
      expect(preview.canDelete, isFalse);
    });

    test('counts reimbursement expense column references alone', () async {
      final category = _category('advance-only');
      final service = _service(
        accounts: [category],
        reimbursementRefCounts: {category.id: 1},
      );

      final preview = await service.previewCategoryDeletion(category.id);

      expect(preview.childCount, 0);
      expect(preview.transactionRefCount, 1);
      expect(preview.canDelete, isFalse);
    });

    test('allows deletion for a clean leaf category', () async {
      final category = _category('clean');
      final service = _service(accounts: [category]);

      final preview = await service.previewCategoryDeletion(category.id);

      expect(preview.canDelete, isTrue);
    });

    test('rejects archived category', () async {
      final archived = _category('archived', archived: true);
      final service = _service(accounts: [archived]);

      await expectLater(
        () => service.previewCategoryDeletion(archived.id),
        throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
      );
    });
  });

  group('CategoryAppService.deleteCategory', () {
    test('rejects deleting an unreferenced system category', () async {
      final category = _category('system-fee', systemKey: SystemKey.feeExpense);
      final repository = _FakeAccountRepository([category]);
      final service = _service(repository: repository);

      await expectLater(
        () => service.deleteCategory(DeleteCategoryCommand(id: category.id)),
        throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
      );
      expect(repository.account(category.id), isNotNull);
    });

    test(
      'physically deletes a category without children or references',
      () async {
        final category = _category('clean');
        final repository = _FakeAccountRepository([category]);
        final service = _service(repository: repository);

        await service.deleteCategory(DeleteCategoryCommand(id: category.id));

        expect(repository.account(category.id), isNull);
      },
    );

    test('rejects deletion while child categories exist', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final repository = _FakeAccountRepository([root, child]);
      final service = _service(repository: repository);

      await expectLater(
        () => service.deleteCategory(DeleteCategoryCommand(id: root.id)),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
      expect(repository.account(root.id), isNotNull);
    });

    test('rejects deletion while entries reference the category', () async {
      final category = _category('referenced');
      final repository = _FakeAccountRepository([category]);
      final service = _service(
        repository: repository,
        entryCounts: {category.id: 1},
      );

      await expectLater(
        () => service.deleteCategory(DeleteCategoryCommand(id: category.id)),
        throwsA(_hasCode(LedgerErrorCode.categoryInUse)),
      );
      expect(repository.account(category.id), isNotNull);
    });

    test(
      'rejects deletion while reimbursement advances reference the category',
      () async {
        final category = _category('advance-referenced');
        final repository = _FakeAccountRepository([category]);
        final service = _service(
          repository: repository,
          reimbursementRefCounts: {category.id: 1},
        );

        await expectLater(
          () => service.deleteCategory(DeleteCategoryCommand(id: category.id)),
          throwsA(_hasCode(LedgerErrorCode.categoryInUse)),
        );
        expect(repository.account(category.id), isNotNull);
      },
    );

    test('deletes a child category independently of its parent', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final repository = _FakeAccountRepository([root, child]);
      final service = _service(
        repository: repository,
        entryCounts: {root.id: 5},
      );

      await service.deleteCategory(DeleteCategoryCommand(id: child.id));

      expect(repository.account(child.id), isNull);
      expect(repository.account(root.id), isNotNull);
    });
  });
}

Matcher _hasCode(LedgerErrorCode code) {
  return isA<BusinessException>().having(
    (exception) => exception.code,
    'code',
    code.code,
  );
}

Account _category(
  String id, {
  String? parentId,
  AccountType type = AccountType.expense,
  bool archived = false,
  SystemKey? systemKey,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
    archivedAt: archived ? DateTime(2026) : null,
    systemKey: systemKey,
  );
}

CategoryAppServiceImpl _service({
  _FakeAccountRepository? repository,
  Iterable<Account> accounts = const [],
  Map<String, int> entryCounts = const {},
  Map<String, int> reimbursementRefCounts = const {},
}) {
  return CategoryAppServiceImpl(
    repository: repository ?? _FakeAccountRepository(accounts),
    transactionRepository: _FakeTransactionRepository(
      entryCounts: entryCounts,
      reimbursementRefCounts: reimbursementRefCounts,
    ),
    transactionRunner: _PassthroughTransactionRunner(),
    idGenerator: SequentialIdGenerator(),
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  Account? account(String id) => _accounts[id];

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
  Future<List<Account>> findByGroupId(String? groupId) async => [
    for (final account in _accounts.values)
      if (account.groupId == groupId) account,
  ];

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

  @override
  Future<void> delete(String id) async {
    _accounts.remove(id);
  }
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository({
    required Map<String, int> entryCounts,
    required Map<String, int> reimbursementRefCounts,
  }) : _entryCounts = entryCounts,
       _reimbursementRefCounts = reimbursementRefCounts;

  final Map<String, int> _entryCounts;
  final Map<String, int> _reimbursementRefCounts;

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) async {
    return {
      for (final id in accountIds)
        if (_entryCounts[id] case final int count when count > 0) id: count,
    };
  }

  @override
  Future<Map<String, int>> countReimbursementExpenseRefs(
    Set<String> accountIds,
  ) async {
    return {
      for (final id in accountIds)
        if (_reimbursementRefCounts[id] case final int count when count > 0)
          id: count,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _PassthroughTransactionRunner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
