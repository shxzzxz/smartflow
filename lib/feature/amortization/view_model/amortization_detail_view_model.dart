import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/money/money.dart';
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

  Future<UiActionOutcome<void>> terminate({
    required DateTime terminatedAt,
    required String refundAccountId,
    required String refundAmountText,
    required String feeText,
    required String? categoryAccountId,
    required String noteText,
  }) async {
    final current = state.value;
    if (current == null) return _invalid('摊销计划尚未加载');
    final refund = Money.tryParse(refundAmountText);
    final fee = feeText.trim().isEmpty ? Money.zero() : Money.tryParse(feeText);
    if (refund == null || refund.minorUnits < 0) {
      return _invalid('请输入有效退款金额');
    }
    if (fee == null || fee.minorUnits < 0) {
      return _invalid('请输入有效手续费');
    }
    final outcome = await guardUiAction(
      _logger,
      'Terminate amortization plan',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .terminate(
            TerminateAmortizationPlanCommand(
              planId: current.plan.id,
              terminatedAt: terminatedAt,
              refundAccountId: refundAccountId,
              refundAmount: refund,
              recognitionCategoryAccountId: categoryAccountId,
              refundFeeAmount: fee.minorUnits == 0 ? null : fee,
              note: noteText.trim().isEmpty ? null : noteText.trim(),
            ),
          ),
    );
    if (outcome is UiActionSuccess) {
      ref
        ..invalidate(amortizationPlanProvider(current.plan.id))
        ..invalidate(amortizationPlansProvider());
    }
    return outcome;
  }

  Future<UiActionOutcome<void>> updateDefaults({
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    required AmortizationReportingScope scope,
  }) async {
    final current = state.value;
    if (current == null) return _invalid('摊销计划尚未加载');
    final outcome = await guardUiAction(
      _logger,
      'Update amortization reporting defaults',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .updateReportingDefaults(
            UpdateAmortizationReportingDefaultsCommand(
              planId: current.plan.id,
              isExcludedFromStats: isExcludedFromStats,
              isExcludedFromBudget: isExcludedFromBudget,
              scope: scope,
            ),
          ),
    );
    if (outcome is UiActionSuccess) {
      ref
        ..invalidate(amortizationPlanProvider(current.plan.id))
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
