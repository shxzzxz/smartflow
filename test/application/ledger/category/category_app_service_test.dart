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

    test(
      'moving a child appends it and compacts the old sibling set',
      () async {
        final sourceParent = _category('source-parent');
        final targetParent = _category('target-parent');
        final moved = _category('moved', parentId: sourceParent.id);
        final remaining = _category('remaining', parentId: sourceParent.id)
          ..sortOrder = 1;
        final target = _category('target', parentId: targetParent.id)
          ..sortOrder = 8;
        final service = _service(
          accounts: [sourceParent, targetParent, moved, remaining, target],
        );

        await service.editCategory(
          EditCategoryCommand(
            id: moved.id,
            parentId: Patch.set(targetParent.id),
          ),
        );

        expect(moved.parentId, targetParent.id);
        expect(moved.sortOrder, 9);
        expect(remaining.sortOrder, 0);
      },
    );

    test('appends a new category after existing siblings', () async {
      final first = _category('first')..sortOrder = 4;
      final second = _category('second')..sortOrder = 9;
      final service = _service(accounts: [first, second]);

      final created = await service.createCategory(
        const CreateCategoryCommand(name: 'Third', type: AccountType.expense),
      );

      expect(created.sortOrder, 10);
    });

    test('reorders the full active sibling set', () async {
      final first = _category('first')..sortOrder = 4;
      final second = _category('second')..sortOrder = 9;
      final child = _category('child', parentId: 'parent')..sortOrder = 1;
      final service = _service(accounts: [first, second, child]);

      await service.reorderCategories(
        const ReorderCategoriesCommand(
          type: AccountType.expense,
          parentId: null,
          orderedIds: ['second', 'first'],
        ),
      );

      expect(second.sortOrder, 0);
      expect(first.sortOrder, 1);
      expect(child.sortOrder, 1);
    });

    test('rejects reordering an incomplete sibling set', () async {
      final first = _category('first');
      final second = _category('second');
      final service = _service(accounts: [first, second]);

      await expectLater(
        () => service.reorderCategories(
          const ReorderCategoriesCommand(
            type: AccountType.expense,
            parentId: null,
            orderedIds: ['second'],
          ),
        ),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
    });
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
        advanceRefCounts: {root.id: 2},
      );

      final preview = await service.previewCategoryDeletion(root.id);

      expect(preview.childCount, 1);
      expect(preview.transactionRefCount, 5);
      expect(preview.canDelete, isFalse);
    });

    test('counts advance expense column references alone', () async {
      final category = _category('advance-only');
      final service = _service(
        accounts: [category],
        advanceRefCounts: {category.id: 1},
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
      'rejects deletion while advance transactions reference the category',
      () async {
        final category = _category('advance-referenced');
        final repository = _FakeAccountRepository([category]);
        final service = _service(
          repository: repository,
          advanceRefCounts: {category.id: 1},
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
  int sortOrder = 0,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
    archivedAt: archived ? DateTime(2026) : null,
    systemKey: systemKey,
    sortOrder: sortOrder,
  );
}

CategoryAppServiceImpl _service({
  _FakeAccountRepository? repository,
  Iterable<Account> accounts = const [],
  Map<String, int> entryCounts = const {},
  Map<String, int> advanceRefCounts = const {},
}) {
  return CategoryAppServiceImpl(
    repository: repository ?? _FakeAccountRepository(accounts),
    transactionRepository: _FakeTransactionRepository(
      entryCounts: entryCounts,
      advanceRefCounts: advanceRefCounts,
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
  Future<List<Account>> findCategorySiblings({
    required AccountType type,
    required String? parentId,
  }) async {
    final siblings =
        [
          for (final account in _accounts.values)
            if (!account.isArchived &&
                account.type == type &&
                account.parentId == parentId)
              account,
        ]..sort((left, right) {
          final order = left.sortOrder.compareTo(right.sortOrder);
          if (order != 0) return order;
          final name = left.name.compareTo(right.name);
          return name != 0 ? name : left.id.compareTo(right.id);
        });
    return siblings;
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
    required Map<String, int> advanceRefCounts,
  }) : _entryCounts = entryCounts,
       _advanceRefCounts = advanceRefCounts;

  final Map<String, int> _entryCounts;
  final Map<String, int> _advanceRefCounts;

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) async {
    return {
      for (final id in accountIds)
        if (_entryCounts[id] case final int count when count > 0) id: count,
    };
  }

  @override
  Future<Map<String, int>> countAdvanceExpenseRefs(
    Set<String> accountIds,
  ) async {
    return {
      for (final id in accountIds)
        if (_advanceRefCounts[id] case final int count when count > 0)
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
