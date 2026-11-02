part of 'transaction_detail_action_dispatcher.dart';

Future<UiActionOutcome<void>> detailVoidOutcomeFromAction(
  Future<void> Function() action,
) {
  return guardUiAction(_logger, 'Transaction detail action', action);
}

UiActionOutcome<void> detailNotEditable(String message) {
  return UiActionOutcome.failure(
    UiError(
      code: LedgerErrorCode.transactionNotEditable.code,
      message: message,
    ),
  );
}

UiActionOutcome<void> detailInvalidCommand(String message) {
  return UiActionOutcome.failure(
    UiError(
      code: LedgerErrorCode.transactionInvalidCommand.code,
      message: message,
    ),
  );
}

Patch<String?> _nullableStringPatch(String? value) {
  return value == null ? const Patch<String?>.clear() : Patch.set(value);
}

Future<UiActionOutcome<void>> _changePostedAt({
  required TransactionReadModel transaction,
  required TransactionUpdateAppService updateService,
  required DateTime value,
}) {
  return detailVoidOutcomeFromAction(() {
    return updateService.updateBasicInfo(
      UpdateTransactionBasicInfoCommand(
        transactionId: transaction.id,
        postedAt: value,
      ),
    );
  });
}
