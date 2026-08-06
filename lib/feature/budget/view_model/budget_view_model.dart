import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'budget_view_model.g.dart';

final _logger = Logger('feature.budget');

@riverpod
class BudgetViewModel extends _$BudgetViewModel {
  @override
  BudgetControlState build(DateTime? initialMonth) {
    final now = ref.watch(currentDateTimeProvider);
    final month = initialMonth ?? now;
    final visibleMonth = DateTime(month.year, month.month);
    final groups =
        ref
            .watch(monthlyBudgetReportProvider(visibleMonth))
            .value
            ?.categoryGroups ??
        const <BudgetCategoryGroup>[];
    return BudgetControlState(
      visibleMonth: visibleMonth,
      categoryGroups: groups,
    );
  }

  Future<UiActionOutcome<bool>> copyPreviousMonthBudgetsOnOpen() {
    return guardUiAction(
      _logger,
      'copy previous month budgets on open',
      () async {
        final now = ref.read(currentDateTimeProvider);
        final visibleMonth = state.visibleMonth;
        if (visibleMonth.year != now.year || visibleMonth.month != now.month) {
          return false;
        }

        final settings = await ref.read(appSettingsViewModelProvider.future);
        if (!settings.copyPreviousMonthBudgetsOnOpen) return false;

        final report =
            await ref
                .read(budgetQueryServiceProvider)
                .watchMonthlyReport(MonthKey.fromDate(visibleMonth))
                .first;
        if (report.totalBudget != null || report.categoryGroups.isNotEmpty) {
          return false;
        }
        return ref
            .read(budgetAppServiceProvider)
            .copyPreviousMonthBudgets(
              CopyPreviousMonthBudgetsCommand(
                month: MonthKey.fromDate(visibleMonth),
              ),
            );
      },
    );
  }

  Future<UiActionOutcome<void>> setBudget({
    required Money amount,
    String? categoryId,
  }) {
    return guardUiAction(_logger, 'set budget', () async {
      await ref
          .read(budgetAppServiceProvider)
          .setBudget(
            SetBudgetCommand(
              month: MonthKey.fromDate(state.visibleMonth),
              categoryId: categoryId,
              amount: amount,
            ),
          );
    });
  }

  Future<UiActionOutcome<void>> deleteBudget(String id) {
    return guardUiAction(_logger, 'delete budget', () async {
      await ref
          .read(budgetAppServiceProvider)
          .deleteBudget(DeleteBudgetCommand(id));
    });
  }

  Future<UiActionOutcome<void>> clearMonthBudgets() {
    return guardUiAction(_logger, 'clear month budgets', () async {
      await ref
          .read(budgetAppServiceProvider)
          .clearMonthBudgets(
            ClearMonthBudgetsCommand(MonthKey.fromDate(state.visibleMonth)),
          );
    });
  }

  Future<UiActionOutcome<void>> reorderCategoryBudgets(
    List<String> orderedBudgetIds,
  ) {
    return guardUiAction(_logger, 'reorder budgets', () async {
      await ref
          .read(budgetAppServiceProvider)
          .reorderCategoryBudgets(
            ReorderCategoryBudgetsCommand(
              month: MonthKey.fromDate(state.visibleMonth),
              orderedBudgetIds: orderedBudgetIds,
            ),
          );
    });
  }

  Future<UiActionOutcome<void>> reorderBudgetGroups(
    int oldIndex,
    int newIndex,
  ) {
    return _reorderCategoryGroups((groups) {
      if (oldIndex < newIndex) newIndex -= 1;
      final moved = groups.removeAt(oldIndex);
      groups.insert(newIndex, moved);
    });
  }

  Future<UiActionOutcome<void>> reorderBudgetsWithinGroup(
    int groupIndex,
    int oldIndex,
    int newIndex,
  ) {
    return _reorderCategoryGroups((groups) {
      if (oldIndex < newIndex) newIndex -= 1;
      final group = groups[groupIndex];
      final children = [...group.childBudgets];
      final moved = children.removeAt(oldIndex);
      children.insert(newIndex, moved);
      groups[groupIndex] = BudgetCategoryGroup(
        id: group.id,
        name: group.name,
        iconKey: group.iconKey,
        sortOrder: group.sortOrder,
        rootBudget: group.rootBudget,
        childBudgets: children,
      );
    });
  }

  Future<UiActionOutcome<void>> _reorderCategoryGroups(
    void Function(List<BudgetCategoryGroup> groups) reorder,
  ) async {
    if (state.savingOrder) {
      return const UiActionOutcome.success(null);
    }
    final previous = state.categoryGroups;
    final next = [...previous];
    reorder(next);
    state = state.copyWith(categoryGroups: next, savingOrder: true);
    final outcome = await reorderCategoryBudgets([
      for (final group in next)
        for (final budget in group.budgets) budget.id,
    ]);
    state = state.copyWith(
      categoryGroups: outcome is UiActionSuccess ? next : previous,
      savingOrder: false,
    );
    return outcome;
  }
}

@riverpod
BudgetPageState budgetPage(Ref ref, DateTime? initialMonth) {
  final control = ref.watch(budgetViewModelProvider(initialMonth));
  final copyEnabled =
      ref
          .watch(appSettingsViewModelProvider)
          .value
          ?.copyPreviousMonthBudgetsOnOpen ??
      false;
  final report = ref.watch(monthlyBudgetReportProvider(control.visibleMonth));
  final categories = ref.watch(categoryTreeProvider(AccountType.expense));

  if (report case AsyncError()) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      copyEnabled: copyEnabled,
      content: const BudgetContentState.error(message: '预算加载失败，请稍后重试'),
    );
  }
  if (categories case AsyncError()) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      copyEnabled: copyEnabled,
      content: const BudgetContentState.error(message: '支出分类加载失败，请稍后重试'),
    );
  }
  final reportValue = report.value;
  final categoryValues = categories.value;
  if (reportValue == null || categoryValues == null) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      copyEnabled: copyEnabled,
      content: const BudgetContentState.loading(),
    );
  }
  return BudgetPageState(
    visibleMonth: control.visibleMonth,
    copyEnabled: copyEnabled,
    content: BudgetContentState.loaded(
      report: reportValue,
      categories: categoryValues,
    ),
  );
}

@riverpod
Stream<List<TransactionListReadModel>> budgetCategoryTransactions(
  Ref ref,
  String categoryId,
  DateTime month,
) {
  final accountLookup = ref.watch(accountLookupProvider).value;
  if (accountLookup == null) return const Stream.empty();
  final categoryIds =
      resolveCategoryAccountIds([
          CategorySelection.withDescendants(categoryId),
        ], accountLookup.byId).toList()
        ..sort();
  final visibleMonth = MonthKey.fromDate(month);
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          categoryAccountIds: categoryIds.toSet(),
          occurredFrom: visibleMonth.start,
          occurredUntil: visibleMonth.nextMonthStart,
          topLevelOnly: true,
          limit: null,
          scope: TransactionScopeFilter.budget,
        ),
      );
}

@riverpod
BudgetDetailPageState budgetDetailPage(
  Ref ref,
  String budgetId,
  DateTime month,
) {
  final report = ref.watch(monthlyBudgetReportProvider(month));
  if (report case AsyncError()) {
    return const BudgetDetailPageState.error(message: '分类预算加载失败，请稍后重试');
  }
  final reportValue = report.value;
  if (reportValue == null) return const BudgetDetailPageState.loading();
  final progress = reportValue.findCategoryBudget(budgetId);
  if (progress == null) return const BudgetDetailPageState.notFound();
  if (progress.categoryId case final categoryId?) {
    final accountLookup = ref.watch(accountLookupProvider);
    if (accountLookup case AsyncError()) {
      return const BudgetDetailPageState.error(message: '分类交易加载失败，请稍后重试');
    }
    final lookup = accountLookup.value;
    if (lookup == null) {
      return const BudgetDetailPageState.loading();
    }
    final transactions = ref.watch(
      budgetCategoryTransactionsProvider(categoryId, month),
    );
    if (transactions case AsyncError()) {
      return const BudgetDetailPageState.error(message: '分类交易加载失败，请稍后重试');
    }
    final transactionValues = transactions.value;
    if (transactionValues == null) {
      return const BudgetDetailPageState.loading();
    }
    return BudgetDetailPageState.loaded(
      month: reportValue.month,
      progress: progress,
      transactions: transactionValues,
      accountLookup: lookup,
    );
  }
  return BudgetDetailPageState.loaded(
    month: reportValue.month,
    progress: progress,
    transactions: const [],
    accountLookup: const AccountLookup({}),
  );
}

class BudgetControlState {
  const BudgetControlState({
    required this.visibleMonth,
    this.categoryGroups = const [],
    this.savingOrder = false,
  });

  final DateTime visibleMonth;
  final List<BudgetCategoryGroup> categoryGroups;
  final bool savingOrder;

  BudgetControlState copyWith({
    List<BudgetCategoryGroup>? categoryGroups,
    bool? savingOrder,
  }) {
    return BudgetControlState(
      visibleMonth: visibleMonth,
      categoryGroups: categoryGroups ?? this.categoryGroups,
      savingOrder: savingOrder ?? this.savingOrder,
    );
  }
}

class BudgetPageState {
  const BudgetPageState({
    required this.visibleMonth,
    required this.copyEnabled,
    required this.content,
  });

  final DateTime visibleMonth;
  final bool copyEnabled;
  final BudgetContentState content;
}

sealed class BudgetContentState {
  const BudgetContentState();

  const factory BudgetContentState.loading() = BudgetContentLoading;

  const factory BudgetContentState.error({required String message}) =
      BudgetContentError;

  const factory BudgetContentState.loaded({
    required MonthlyBudgetReport report,
    required List<CategoryNode> categories,
  }) = BudgetContentLoaded;
}

final class BudgetContentLoading extends BudgetContentState {
  const BudgetContentLoading();
}

final class BudgetContentError extends BudgetContentState {
  const BudgetContentError({required this.message});

  final String message;
}

final class BudgetContentLoaded extends BudgetContentState {
  const BudgetContentLoaded({required this.report, required this.categories});

  final MonthlyBudgetReport report;
  final List<CategoryNode> categories;
}

sealed class BudgetDetailPageState {
  const BudgetDetailPageState();

  const factory BudgetDetailPageState.loading() = BudgetDetailPageLoading;

  const factory BudgetDetailPageState.error({required String message}) =
      BudgetDetailPageError;

  const factory BudgetDetailPageState.notFound() = BudgetDetailPageNotFound;

  const factory BudgetDetailPageState.loaded({
    required MonthKey month,
    required BudgetProgress progress,
    required List<TransactionListReadModel> transactions,
    required AccountLookup accountLookup,
  }) = BudgetDetailPageLoaded;
}

final class BudgetDetailPageLoading extends BudgetDetailPageState {
  const BudgetDetailPageLoading();
}

final class BudgetDetailPageError extends BudgetDetailPageState {
  const BudgetDetailPageError({required this.message});

  final String message;
}

final class BudgetDetailPageNotFound extends BudgetDetailPageState {
  const BudgetDetailPageNotFound();
}

final class BudgetDetailPageLoaded extends BudgetDetailPageState {
  const BudgetDetailPageLoaded({
    required this.month,
    required this.progress,
    required this.transactions,
    required this.accountLookup,
  });

  final MonthKey month;
  final BudgetProgress progress;
  final List<TransactionListReadModel> transactions;
  final AccountLookup accountLookup;
}
