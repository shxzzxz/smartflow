import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/money/money.dart';
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
    final transactionIds = {
      plan.initialTransactionId,
      for (final refund in plan.refunds) refund.transferTransactionId,
      if (plan.termination case final termination?) ...[
        ?termination.recognitionTransactionId,
        ?termination.returnTransactionId,
      ],
    };
    final transactions = await ref
        .read(transactionQueryServiceProvider)
        .findTransactionsByIds(transactionIds);
    final transactionById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    return AmortizationDetailState(
      plan: plan,
      activities: _activitiesFor(plan, transactionById)..sort(_byOccurredAt),
    );
  }

  Future<UiActionOutcome<void>> deleteRefund(String refundId, {DateTime? now}) {
    final current = state.value;
    if (current == null) return Future.value(_invalid('摊销计划尚未加载'));
    return _run(
      current.plan.id,
      'Delete amortization refund',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .deleteRefund(
            DeleteAmortizationRefundCommand(
              planId: current.plan.id,
              refundId: refundId,
              now: now ?? DateTime.now(),
            ),
          ),
    );
  }

  Future<UiActionOutcome<void>> deleteTermination({DateTime? now}) {
    final current = state.value;
    if (current == null) return Future.value(_invalid('摊销计划尚未加载'));
    final terminationId = current.plan.termination?.id;
    if (terminationId == null) {
      return Future.value(_invalid('摊销终止不存在'));
    }
    return _run(
      current.plan.id,
      'Delete amortization termination',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .deleteTermination(
            DeleteAmortizationTerminationCommand(
              planId: current.plan.id,
              terminationId: terminationId,
              now: now ?? DateTime.now(),
            ),
          )
          .then((_) {}),
    );
  }

  Future<UiActionOutcome<void>> deletePlan() {
    final current = state.value;
    if (current == null) return Future.value(_invalid('摊销计划尚未加载'));
    return _run(
      current.plan.id,
      'Delete amortization plan',
      () => ref
          .read(amortizationPlanAppServiceProvider)
          .deletePlan(DeleteAmortizationPlanCommand(planId: current.plan.id)),
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
  const AmortizationDetailState({required this.plan, required this.activities});

  final AmortizationPlan plan;
  final List<AmortizationActivity> activities;
}

enum AmortizationActivityKind { initial, refund, termination }

class AmortizationActivity {
  const AmortizationActivity({
    required this.id,
    required this.kind,
    required this.transactionId,
    required this.occurredAt,
    required this.amount,
    this.refundId,
    this.terminationReturnAmount = const Money(minorUnits: 0),
    this.terminationRecognitionAmount = const Money(minorUnits: 0),
  });

  final String id;
  final AmortizationActivityKind kind;
  final String transactionId;
  final DateTime occurredAt;
  final Money amount;
  final String? refundId;
  final Money terminationReturnAmount;
  final Money terminationRecognitionAmount;
}

List<AmortizationActivity> _activitiesFor(
  AmortizationPlan plan,
  Map<String, TransactionReadModel> transactionById,
) {
  final result = <AmortizationActivity>[];
  final initial = transactionById[plan.initialTransactionId];
  if (initial != null) {
    result.add(
      AmortizationActivity(
        id: plan.initialTransactionId,
        kind: AmortizationActivityKind.initial,
        transactionId: plan.initialTransactionId,
        occurredAt: initial.occurredAt,
        amount: plan.originalAmount,
      ),
    );
  }
  for (final refund in plan.refunds) {
    final transaction = transactionById[refund.transferTransactionId];
    if (transaction == null) continue;
    result.add(
      AmortizationActivity(
        id: refund.id,
        kind: AmortizationActivityKind.refund,
        transactionId: refund.transferTransactionId,
        refundId: refund.id,
        occurredAt: transaction.occurredAt,
        amount: refund.amount,
      ),
    );
  }
  final termination = plan.termination;
  if (termination != null) {
    final transactionId =
        termination.recognitionTransactionId ?? termination.returnTransactionId;
    final transaction = transactionById[transactionId];
    if (transactionId != null && transaction != null) {
      final remainingBeforeTermination = subtractAllocations(
        base: plan.currentCategoryAllocations,
        reductions: plan.recognizedCategoryAllocations,
      );
      result.add(
        AmortizationActivity(
          id: termination.id,
          kind: AmortizationActivityKind.termination,
          transactionId: transactionId,
          occurredAt: transaction.occurredAt,
          amount: termination.returnAmount,
          terminationReturnAmount: termination.returnAmount,
          terminationRecognitionAmount:
              sumAllocations(remainingBeforeTermination) -
              termination.returnAmount,
        ),
      );
    }
  }
  return result;
}

int _byOccurredAt(AmortizationActivity left, AmortizationActivity right) {
  final byDate = right.occurredAt.compareTo(left.occurredAt);
  return byDate != 0 ? byDate : right.id.compareTo(left.id);
}
