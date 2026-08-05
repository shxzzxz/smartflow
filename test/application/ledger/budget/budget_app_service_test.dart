import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/budget/command/budget_app_service.dart';
import 'package:smartflow/application/ledger/budget/command/budget_command.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/budget.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/budget_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

void main() {
  final month = MonthKey(year: 2026, month: 8);

  test('同月总预算与父子分类预算可独立设置且不校验金额之和', () async {
    final budgets = _MemoryBudgetRepository();
    final service = BudgetAppServiceImpl(
      budgets: budgets,
      accounts: _MemoryAccountRepository([
        _expenseCategory('food', '餐饮'),
        _expenseCategory('lunch', '午餐', parentId: 'food'),
      ]),
      transactionRunner: const _DirectTransactionRunner(),
      idGenerator: _SequenceIdGenerator(),
    );

    await service.setBudget(
      SetBudgetCommand(month: month, amount: const Money(minorUnits: 80000)),
    );
    await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'food',
        amount: const Money(minorUnits: 100000),
      ),
    );
    await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'lunch',
        amount: const Money(minorUnits: 120000),
      ),
    );

    final saved = await budgets.findByMonth(month);
    expect(saved, hasLength(3));
    expect(saved.singleWhere((item) => item.isTotal).amount.minorUnits, 80000);
    expect(
      saved.singleWhere((item) => item.categoryId == 'food').amount.minorUnits,
      100000,
    );
    expect(
      saved.singleWhere((item) => item.categoryId == 'lunch').amount.minorUnits,
      120000,
    );
  });

  test('重复设置同一月分类预算保留身份和排序位置', () async {
    final budgets = _MemoryBudgetRepository();
    final service = BudgetAppServiceImpl(
      budgets: budgets,
      accounts: _MemoryAccountRepository([_expenseCategory('food', '餐饮')]),
      transactionRunner: const _DirectTransactionRunner(),
      idGenerator: _SequenceIdGenerator(),
    );

    final created = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'food',
        amount: const Money(minorUnits: 100000),
      ),
    );
    final updated = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'food',
        amount: const Money(minorUnits: 150000),
      ),
    );

    expect(updated.id, created.id);
    expect(updated.sortOrder, created.sortOrder);
    expect((await budgets.findByMonth(month)), hasLength(1));
  });

  test('分类预算顺序按提交的完整 id 列表持久化', () async {
    final budgets = _MemoryBudgetRepository();
    final service = BudgetAppServiceImpl(
      budgets: budgets,
      accounts: _MemoryAccountRepository([
        _expenseCategory('food', '餐饮'),
        _expenseCategory('travel', '出行'),
      ]),
      transactionRunner: const _DirectTransactionRunner(),
      idGenerator: _SequenceIdGenerator(),
    );
    final food = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'food',
        amount: const Money(minorUnits: 100000),
      ),
    );
    final travel = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'travel',
        amount: const Money(minorUnits: 50000),
      ),
    );

    await service.reorderCategoryBudgets(
      ReorderCategoryBudgetsCommand(
        month: month,
        orderedBudgetIds: [travel.id, food.id],
      ),
    );

    final saved = await budgets.findByMonth(month);
    expect(saved.where((item) => !item.isTotal).map((item) => item.id), [
      travel.id,
      food.id,
    ]);
  });

  test('不可见遗留预算不阻止可见分类预算排序', () async {
    final budgets = _MemoryBudgetRepository();
    await budgets.save(
      Budget(
        id: 'legacy-budget',
        month: month,
        categoryId: 'deleted-category',
        amount: const Money(minorUnits: 30000),
        sortOrder: 7,
      ),
    );
    final service = BudgetAppServiceImpl(
      budgets: budgets,
      accounts: _MemoryAccountRepository([
        _expenseCategory('food', '餐饮'),
        _expenseCategory('travel', '出行'),
      ]),
      transactionRunner: const _DirectTransactionRunner(),
      idGenerator: _SequenceIdGenerator(),
    );
    final food = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'food',
        amount: const Money(minorUnits: 100000),
      ),
    );
    final travel = await service.setBudget(
      SetBudgetCommand(
        month: month,
        categoryId: 'travel',
        amount: const Money(minorUnits: 50000),
      ),
    );

    await service.reorderCategoryBudgets(
      ReorderCategoryBudgetsCommand(
        month: month,
        orderedBudgetIds: [travel.id, food.id],
      ),
    );

    final saved = await budgets.findByMonth(month);
    expect(saved.singleWhere((item) => item.id == travel.id).sortOrder, 0);
    expect(saved.singleWhere((item) => item.id == food.id).sortOrder, 1);
    expect(
      saved.singleWhere((item) => item.id == 'legacy-budget').sortOrder,
      7,
    );
  });
}

Account _expenseCategory(String id, String name, {String? parentId}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    balance: Money.zero(),
    parentId: parentId,
  );
}

class _MemoryBudgetRepository implements BudgetRepository {
  final _items = <String, Budget>{};

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<Budget?> findById(String id) async => _items[id];

  @override
  Future<List<Budget>> findByMonth(MonthKey month) async {
    return [
      for (final item in _items.values)
        if (item.month == month) item,
    ]..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }

  @override
  Future<Budget?> findByMonthAndCategory(
    MonthKey month,
    String? categoryId,
  ) async {
    for (final item in _items.values) {
      if (item.month == month && item.categoryId == categoryId) return item;
    }
    return null;
  }

  @override
  Future<void> save(Budget budget) async => _items[budget.id] = budget;

  @override
  Future<void> saveAll(Iterable<Budget> budgets) async {
    for (final budget in budgets) {
      _items[budget.id] = budget;
    }
  }
}

class _MemoryAccountRepository implements AccountRepository {
  _MemoryAccountRepository(Iterable<Account> accounts)
    : _items = {for (final item in accounts) item.id: item};

  final Map<String, Account> _items;

  @override
  Future<Account?> findById(String id) async => _items[id];

  @override
  Future<List<Account>> findByIds(Set<String> ids) async => [
    for (final id in ids)
      if (_items[id] case final item?) item,
  ];

  @override
  Future<List<Account>> findChildrenOf(String parentId) async => [
    for (final item in _items.values)
      if (item.parentId == parentId) item,
  ];

  @override
  Future<List<Account>> findByGroupId(String? groupId) async => const [];

  @override
  Future<void> create(Account account) async => _items[account.id] = account;

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<void> save(Account account) async => _items[account.id] = account;

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    for (final account in accounts) {
      _items[account.id] = account;
    }
  }
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _SequenceIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'budget-${_next++}';
}
