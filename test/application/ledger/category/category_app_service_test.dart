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
    test('reports dispositions, entry counts and mounts for the tree', () async {
      final root = _category('root');
      final child1 = _category('child1', parentId: root.id);
      final child2 = _category('child2', parentId: root.id);
      final mount = _category('mount', parentId: child1.id, archived: true);
      final service = _service(
        accounts: [root, child1, child2, mount],
        entryCounts: {root.id: 3, child1.id: 2},
      );

      final preview = await service.previewCategoryDeletion(root.id);

      expect(preview.requiresMergeTarget, isTrue);
      expect(preview.totalEntryCount, 5);
      expect(preview.root.disposition, CategoryDeletionDisposition.archiveMerge);
      expect(preview.children, hasLength(2));
      expect(
        preview.children.singleWhere((n) => n.category.id == child1.id)
            .disposition,
        CategoryDeletionDisposition.archiveMerge,
      );
      expect(
        preview.children.singleWhere((n) => n.category.id == child2.id)
            .disposition,
        CategoryDeletionDisposition.physicalDelete,
      );
      expect(preview.mounts.single.id, mount.id);
      expect(preview.excludedTargetIds, {root.id, child1.id, child2.id});
    });

    test('does not require merge target when tree is unreferenced', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final service = _service(accounts: [root, child]);

      final preview = await service.previewCategoryDeletion(root.id);

      expect(preview.requiresMergeTarget, isFalse);
      expect(preview.totalEntryCount, 0);
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
    test('physically deletes an unreferenced tree', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final repository = _FakeAccountRepository([root, child]);
      final service = _service(repository: repository);

      await service.deleteCategory(DeleteCategoryCommand(id: root.id));

      expect(repository.account(root.id), isNull);
      expect(repository.account(child.id), isNull);
    });

    test('requires merge target when tree is referenced', () async {
      final root = _category('root');
      final service = _service(
        accounts: [root],
        entryCounts: {root.id: 1},
      );

      await expectLater(
        () => service.deleteCategory(DeleteCategoryCommand(id: root.id)),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
    });

    test('archives referenced node onto merge target', () async {
      final root = _category('root');
      final target = _category('target');
      final repository = _FakeAccountRepository([root, target]);
      final service = _service(
        repository: repository,
        entryCounts: {root.id: 2},
      );

      await service.deleteCategory(
        DeleteCategoryCommand(id: root.id, mergeTargetId: target.id),
      );

      final archived = repository.account(root.id)!;
      expect(archived.isArchived, isTrue);
      expect(archived.parentId, target.id);
    });

    test(
      'cascades: archives referenced nodes, deletes unreferenced ones',
      () async {
        final root = _category('root');
        final referencedChild = _category('referenced', parentId: root.id);
        final unreferencedChild = _category('unreferenced', parentId: root.id);
        final target = _category('target');
        final repository = _FakeAccountRepository([
          root,
          referencedChild,
          unreferencedChild,
          target,
        ]);
        final service = _service(
          repository: repository,
          entryCounts: {referencedChild.id: 4},
        );

        await service.deleteCategory(
          DeleteCategoryCommand(id: root.id, mergeTargetId: target.id),
        );

        expect(repository.account(root.id), isNull);
        expect(repository.account(unreferencedChild.id), isNull);
        final archived = repository.account(referencedChild.id)!;
        expect(archived.isArchived, isTrue);
        expect(archived.parentId, target.id);
      },
    );

    test('remounts archived mounts onto the new merge target', () async {
      final root = _category('root');
      final mount = _category('mount', parentId: root.id, archived: true);
      final target = _category('target');
      final repository = _FakeAccountRepository([root, mount, target]);
      final service = _service(
        repository: repository,
        entryCounts: {root.id: 1},
      );

      await service.deleteCategory(
        DeleteCategoryCommand(id: root.id, mergeTargetId: target.id),
      );

      final remounted = repository.account(mount.id)!;
      expect(remounted.isArchived, isTrue);
      expect(remounted.parentId, target.id);
    });

    test(
      'requires merge target when tree only carries archived mounts',
      () async {
        final root = _category('root');
        final mount = _category('mount', parentId: root.id, archived: true);
        final service = _service(accounts: [root, mount]);

        await expectLater(
          () => service.deleteCategory(DeleteCategoryCommand(id: root.id)),
          throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
        );
      },
    );

    test('rejects merge target inside the deleted subtree', () async {
      final root = _category('root');
      final child = _category('child', parentId: root.id);
      final service = _service(
        accounts: [root, child],
        entryCounts: {root.id: 1},
      );

      await expectLater(
        () => service.deleteCategory(
          DeleteCategoryCommand(id: root.id, mergeTargetId: child.id),
        ),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
    });

    test('rejects merge target of a different category type', () async {
      final root = _category('root');
      final incomeTarget = _category('income-target', type: AccountType.income);
      final service = _service(
        accounts: [root, incomeTarget],
        entryCounts: {root.id: 1},
      );

      await expectLater(
        () => service.deleteCategory(
          DeleteCategoryCommand(id: root.id, mergeTargetId: incomeTarget.id),
        ),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
    });

    test('rejects archived merge target', () async {
      final root = _category('root');
      final archivedTarget = _category('archived-target', archived: true);
      final service = _service(
        accounts: [root, archivedTarget],
        entryCounts: {root.id: 1},
      );

      await expectLater(
        () => service.deleteCategory(
          DeleteCategoryCommand(
            id: root.id,
            mergeTargetId: archivedTarget.id,
          ),
        ),
        throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
      );
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
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
    archivedAt: archived ? DateTime(2026) : null,
  );
}

CategoryAppServiceImpl _service({
  _FakeAccountRepository? repository,
  Iterable<Account> accounts = const [],
  Map<String, int> entryCounts = const {},
}) {
  return CategoryAppServiceImpl(
    repository: repository ?? _FakeAccountRepository(accounts),
    transactionRepository: _FakeTransactionRepository(entryCounts),
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
  Future<List<Account>> findArchivedMountsOf(Set<String> categoryIds) async {
    return [
      for (final account in _accounts.values)
        if (account.isArchived && categoryIds.contains(account.parentId))
          account,
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

  @override
  Future<void> delete(String id) async {
    _accounts.remove(id);
  }
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this._entryCounts);

  final Map<String, int> _entryCounts;

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) async {
    return {
      for (final id in accountIds)
        if (_entryCounts[id] case final int count when count > 0) id: count,
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
