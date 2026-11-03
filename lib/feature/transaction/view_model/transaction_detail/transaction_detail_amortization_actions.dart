part of 'transaction_detail_view_model.dart';

final class _AmortizationActionDispatcher
    implements _TransactionDetailActionDispatcher {
  const _AmortizationActionDispatcher(
    this.transaction, {
    required this.owner,
    required this.updateService,
    required this.amortizationAppService,
  });

  final TransactionReadModel transaction;
  final AmortizationTransactionDetailOwnerContext owner;
  final TransactionUpdateAppService updateService;
  final AmortizationPlanAppService amortizationAppService;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return switch (owner.factKind) {
      AmortizationTransactionFactKind.refund => detailVoidOutcomeFromAction(
        () => amortizationAppService.deleteRefund(
          DeleteAmortizationRefundCommand(
            planId: owner.ownerId,
            refundId: owner.refundId!,
            now: DateTime.now(),
          ),
        ),
      ),
      AmortizationTransactionFactKind.terminationRecognition ||
      AmortizationTransactionFactKind.terminationReturn =>
        detailVoidOutcomeFromAction(
          () => amortizationAppService.deleteTermination(
            DeleteAmortizationTerminationCommand(
              planId: owner.ownerId,
              now: DateTime.now(),
            ),
          ),
        ),
      _ => detailVoidOutcomeFromAction(
        () => amortizationAppService.deletePlan(
          DeleteAmortizationPlanCommand(planId: owner.ownerId),
        ),
      ),
    };
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          note: _nullableStringPatch(value),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          occurredAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) async {
    return _changePostedAt(
      transaction: transaction,
      updateService: updateService,
      value: value,
    );
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  }) async => detailNotEditable('摊销计划账户由计划控制');
}
