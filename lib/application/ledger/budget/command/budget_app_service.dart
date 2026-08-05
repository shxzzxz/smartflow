import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/ledger/entity/budget.dart';
import '../../../../domain/ledger/port/account_repository.dart';
import '../../../../domain/ledger/port/budget_repository.dart';
import '../../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'budget_command.dart';

abstract interface class BudgetAppService {
  Future<Budget> setBudget(SetBudgetCommand command);

  Future<void> deleteBudget(DeleteBudgetCommand command);

  Future<void> reorderCategoryBudgets(ReorderCategoryBudgetsCommand command);
}

class BudgetAppServiceImpl implements BudgetAppService {
  const BudgetAppServiceImpl({
    required BudgetRepository budgets,
    required AccountRepository accounts,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _budgets = budgets,
       _accounts = accounts,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final BudgetRepository _budgets;
  final AccountRepository _accounts;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;

  @override
  Future<Budget> setBudget(SetBudgetCommand command) {
    return _runner.run(() async {
      if (command.amount.minorUnits < 0) {
        throw BusinessException(
          LedgerErrorCode.budgetInvalidCommand,
          message: 'Budget amount cannot be negative.',
        );
      }
      final categoryId = command.categoryId;
      if (categoryId != null) {
        final category = await _accounts.findById(categoryId);
        if (category == null ||
            category.type != AccountType.expense ||
            category.isArchived ||
            !category.isManageableCategory) {
          throw BusinessException(LedgerErrorCode.categoryUnavailable);
        }
      }

      final existing = await _budgets.findByMonthAndCategory(
        command.month,
        categoryId,
      );
      if (existing != null) {
        existing.changeAmount(command.amount);
        await _budgets.save(existing);
        return existing;
      }

      final monthBudgets = await _budgets.findByMonth(command.month);
      final nextSortOrder =
          categoryId == null
              ? 0
              : monthBudgets
                      .where((item) => !item.isTotal)
                      .fold<int>(
                        -1,
                        (max, item) =>
                            item.sortOrder > max ? item.sortOrder : max,
                      ) +
                  1;
      final budget = Budget(
        id: _idGenerator.newId(),
        month: command.month,
        categoryId: categoryId,
        amount: command.amount,
        sortOrder: nextSortOrder,
      );
      await _budgets.save(budget);
      return budget;
    });
  }

  @override
  Future<void> deleteBudget(DeleteBudgetCommand command) {
    return _runner.run(() async {
      if (await _budgets.findById(command.id) == null) {
        throw BusinessException(LedgerErrorCode.budgetNotFound);
      }
      await _budgets.delete(command.id);
    });
  }

  @override
  Future<void> reorderCategoryBudgets(ReorderCategoryBudgetsCommand command) {
    return _runner.run(() async {
      final budgets =
          (await _budgets.findByMonth(
            command.month,
          )).where((item) => !item.isTotal).toList();
      final budgetsById = {for (final budget in budgets) budget.id: budget};
      final requestedIds = command.orderedBudgetIds.toSet();
      if (requestedIds.length != command.orderedBudgetIds.length ||
          !budgetsById.keys.toSet().containsAll(requestedIds)) {
        throw BusinessException(
          LedgerErrorCode.budgetInvalidCommand,
          message: 'Budget order contains an unknown or duplicate budget.',
        );
      }
      for (var index = 0; index < command.orderedBudgetIds.length; index++) {
        budgetsById[command.orderedBudgetIds[index]]!.reorder(index);
      }
      await _budgets.saveAll([
        for (final id in command.orderedBudgetIds) budgetsById[id]!,
      ]);
    });
  }
}
