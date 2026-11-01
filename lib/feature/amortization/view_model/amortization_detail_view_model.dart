import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/amortization_providers.dart';

part 'amortization_detail_view_model.g.dart';

final _logger = Logger('feature.amortization.detail');

@riverpod
class AmortizationDetailViewModel extends _$AmortizationDetailViewModel {
  @override
  Future<AmortizationDetailState?> build(String planId) async {
    final plan = await ref.watch(amortizationPlanProvider(planId).future);
    if (plan == null) return null;
    final accounts = await ref.watch(accountListProvider.future);
    final categories = await ref.watch(
      categoryTreeProvider(
        plan.kind == AmortizationKind.prepaidExpense
            ? AccountType.expense
            : AccountType.income,
      ).future,
    );
    return AmortizationDetailState(
      plan: plan,
      settlementAccounts: accountsMatchingSelectionPurpose(
        accounts,
        AccountSelectionPurpose.settlement,
      ),
      categoryAccounts: [
        for (final node in categories) ...[node.account, ...node.children],
      ],
    );
  }

  Future<UiActionOutcome<void>> refund({
    required DateTime occurredAt,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) {
    final current = state.value;
    if (current == null) return Future.value(_invalid('摊销计划尚未加载'));
    if (sumAllocations(categoryAllocations).minorUnits <= 0 ||
        sumAllocations(categoryAllocations) !=
            sumAllocations(settlementAllocations)) {
      return Future.value(_invalid('退款分类与账户金额必须相等且大于零'));
    }
    return _run(
      current.plan.id,
      'Create amortization refund',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .refund(
            CreateAmortizationRefundCommand(
              planId: current.plan.id,
              categoryAllocations: categoryAllocations,
              settlementAllocations: settlementAllocations,
              occurredAt: occurredAt,
            ),
          )
          .then((_) {}),
    );
  }

  Future<UiActionOutcome<void>> terminate({
    required DateTime terminatedAt,
    required List<AccountAmountAllocation> categoryReturnAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) {
    final current = state.value;
    if (current == null) return Future.value(_invalid('摊销计划尚未加载'));
    if (sumAllocations(categoryReturnAllocations) !=
        sumAllocations(settlementAllocations)) {
      return Future.value(_invalid('终止分类退还与账户退还金额必须相等'));
    }
    return _run(
      current.plan.id,
      'Terminate amortization plan',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .terminate(
            TerminateAmortizationPlanCommand(
              planId: current.plan.id,
              terminatedAt: terminatedAt,
              categoryReturnAllocations: categoryReturnAllocations,
              settlementAllocations: settlementAllocations,
            ),
          )
          .then((_) {}),
    );
  }

  Future<UiActionOutcome<void>> _run(
    String planId,
    String operation,
    Future<void> Function() body,
  ) async {
    final outcome = await guardUiAction(_logger, operation, body);
    if (outcome is UiActionSuccess) {
      ref
        ..invalidate(amortizationPlanProvider(planId))
        ..invalidate(amortizationPlansProvider());
    }
    return outcome;
  }

  UiActionOutcome<void> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: 'orchestration.amortization.invalid_command',
        message: message,
      ),
    );
  }
}

class AmortizationDetailState {
  const AmortizationDetailState({
    required this.plan,
    required this.settlementAccounts,
    required this.categoryAccounts,
  });

  final AmortizationPlan plan;
  final List<Account> settlementAccounts;
  final List<Account> categoryAccounts;
}
