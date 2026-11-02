part of 'transaction_detail_action_dispatcher.dart';

final class _AmortizationActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _AmortizationActionDispatcher(
    this.transaction, {
    required this.updateService,
  });

  final TransactionReadModel transaction;
  final TransactionUpdateAppService updateService;

  @override
  Future<UiActionOutcome<void>> delete() async =>
      detailNotEditable('请在摊销计划中终止，不能单独删除计划交易');

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
