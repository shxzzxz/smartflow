import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
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
    return BudgetControlState(visibleMonth: DateTime(month.year, month.month));
  }

  void pickMonth(DateTime month) {
    state = BudgetControlState(visibleMonth: DateTime(month.year, month.month));
  }

  void shiftMonth(int delta) {
    final month = state.visibleMonth;
    pickMonth(DateTime(month.year, month.month + delta));
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
}

@riverpod
BudgetPageState budgetPage(Ref ref, DateTime? initialMonth) {
  final control = ref.watch(budgetViewModelProvider(initialMonth));
  final report = ref.watch(monthlyBudgetReportProvider(control.visibleMonth));
  final categories = ref.watch(categoryTreeProvider(AccountType.expense));

  if (report case AsyncError()) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      content: const BudgetContentState.error(message: '预算加载失败，请稍后重试'),
    );
  }
  if (categories case AsyncError()) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      content: const BudgetContentState.error(message: '支出分类加载失败，请稍后重试'),
    );
  }
  final reportValue = report.value;
  final categoryValues = categories.value;
  if (reportValue == null || categoryValues == null) {
    return BudgetPageState(
      visibleMonth: control.visibleMonth,
      content: const BudgetContentState.loading(),
    );
  }
  return BudgetPageState(
    visibleMonth: control.visibleMonth,
    content: BudgetContentState.loaded(
      report: reportValue,
      categories: categoryValues,
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
  return BudgetDetailPageState.loaded(
    month: reportValue.month,
    progress: progress,
  );
}

class BudgetControlState {
  const BudgetControlState({required this.visibleMonth});

  final DateTime visibleMonth;
}

class BudgetPageState {
  const BudgetPageState({required this.visibleMonth, required this.content});

  final DateTime visibleMonth;
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
  const BudgetDetailPageLoaded({required this.month, required this.progress});

  final MonthKey month;
  final BudgetProgress progress;
}
