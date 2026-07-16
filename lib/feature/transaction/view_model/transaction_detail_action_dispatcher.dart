import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';

abstract interface class TransactionDetailActionDispatcher {
  Future<UiActionOutcome<void>> delete();

  Future<UiActionOutcome<void>> changeNote(String? value);

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value);

  Future<UiActionOutcome<void>> changePostedAt(DateTime value);

  Future<UiActionOutcome<void>> changeSettlementAccount(String accountId);
}

TransactionDetailActionDispatcher createTransactionDetailActionDispatcher({
  required Transaction transaction,
  required TransactionCorrectionAppService correctionService,
  required TransactionUpdateAppService updateService,
  required InstallmentAppService installmentAppService,
  required RepaymentAppService repaymentAppService,
}) {
  final ownership = transaction.ownership;
  if (ownership == null) {
    return _DefaultActionDispatcher(
      transaction: transaction,
      correctionService: correctionService,
      updateService: updateService,
    );
  }

  if (ownership.ownerType == installmentOwnerType &&
      ownership.ownerId != null) {
    final role = InstallmentOwnerRole.fromWire(ownership.ownerRole);
    if (role != null) {
      return _InstallmentActionDispatcher(
        transaction: transaction,
        installmentAppService: installmentAppService,
        updateService: updateService,
        contractId: ownership.ownerId!,
      );
    }
  }

  if (ownership.ownerType == creditRepaymentOwnerType &&
      ownership.ownerId != null) {
    final repaymentType = _repaymentTypeFromOwnerRole(ownership.ownerRole);
    if (repaymentType != null) {
      return _CreditRepaymentActionDispatcher(
        transaction: transaction,
        repaymentAppService: repaymentAppService,
        updateService: updateService,
        repaymentId: ownership.ownerId!,
      );
    }
  }

  return _UnknownActionDispatcher(
    transaction: transaction,
    updateService: updateService,
  );
}

RepaymentType? _repaymentTypeFromOwnerRole(String? ownerRole) {
  if (ownerRole == null) return null;
  try {
    return RepaymentType.fromCode(ownerRole);
  } on ArgumentError {
    return null;
  }
}

Future<UiActionOutcome<void>> detailVoidOutcomeFromAction(
  Future<void> Function() action,
) async {
  try {
    await action();
    return const UiActionOutcome.success(null);
  } on AppException catch (exception) {
    return UiActionOutcome.failure(UiError.fromException(exception));
  } on Exception {
    return const UiActionOutcome.failure(UiError.unknown());
  }
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

final class _DefaultActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _DefaultActionDispatcher({
    required this.transaction,
    required this.correctionService,
    required this.updateService,
  });

  final Transaction transaction;
  final TransactionCorrectionAppService correctionService;
  final TransactionUpdateAppService updateService;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return correctionService.deleteTransaction(
        DeleteTransactionCommand(transactionId: transaction.id),
      );
    });
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
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          postedAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    return detailNotEditable('结算账户变更需要通过更正交易完成');
  }
}

final class _InstallmentActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _InstallmentActionDispatcher({
    required this.transaction,
    required this.installmentAppService,
    required this.updateService,
    required this.contractId,
  });

  final Transaction transaction;
  final InstallmentAppService installmentAppService;
  final TransactionUpdateAppService updateService;
  final String contractId;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.deleteContract(
        DeleteContractCommand(contractId: contractId),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.updateContract(
        UpdateContractCommand(
          contractId: contractId,
          note:
              value == null
                  ? const Patch<String>.clear()
                  : Patch<String>.set(value),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.updateContract(
        UpdateContractCommand(contractId: contractId, borrowingDate: value),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          postedAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.updateContract(
        UpdateContractCommand(
          contractId: contractId,
          disbursementAccountId: accountId,
        ),
      );
    });
  }
}

final class _CreditRepaymentActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _CreditRepaymentActionDispatcher({
    required this.transaction,
    required this.repaymentAppService,
    required this.updateService,
    required this.repaymentId,
  });

  final Transaction transaction;
  final RepaymentAppService repaymentAppService;
  final TransactionUpdateAppService updateService;
  final String repaymentId;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return repaymentAppService.deleteRepayment(
        DeleteCreditRepaymentCommand(repaymentId: repaymentId),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    return detailVoidOutcomeFromAction(() {
      return repaymentAppService.editRepaymentTransaction(
        EditCreditRepaymentTransactionCommand(
          repaymentId: repaymentId,
          note: _nullableStringPatch(value),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return repaymentAppService.editRepaymentTransaction(
        EditCreditRepaymentTransactionCommand(
          repaymentId: repaymentId,
          occurredAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          postedAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    return detailVoidOutcomeFromAction(() {
      return repaymentAppService.editRepaymentTransaction(
        EditCreditRepaymentTransactionCommand(
          repaymentId: repaymentId,
          paidFromAccountId: accountId,
        ),
      );
    });
  }
}

final class _UnknownActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _UnknownActionDispatcher({
    required this.transaction,
    required this.updateService,
  });

  final Transaction transaction;
  final TransactionUpdateAppService updateService;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间');
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
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间');
  }

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return updateService.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: transaction.id,
          postedAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间');
  }
}
