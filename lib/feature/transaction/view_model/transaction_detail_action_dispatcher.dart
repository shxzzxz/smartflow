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

  Future<UiActionOutcome<void>> changeSettlementAccount(String accountId);
}

TransactionDetailActionDispatcher createTransactionDetailActionDispatcher({
  required Transaction transaction,
  required TransactionCorrectionAppService correctionService,
  required TransactionUpdateAppService updateService,
  required InstallmentService installmentService,
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
        installmentService: installmentService,
        contractId: ownership.ownerId!,
        role: role,
      );
    }
  }

  return _UnknownActionDispatcher(
    transaction: transaction,
    updateService: updateService,
  );
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
    required this.installmentService,
    required this.contractId,
    required this.role,
  });

  final Transaction transaction;
  final InstallmentService installmentService;
  final String contractId;
  final InstallmentOwnerRole role;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return switch (role) {
        InstallmentOwnerRole.disbursement => installmentService.deleteContract(
          DeleteContractCommand(contractId: contractId),
        ),
        InstallmentOwnerRole.scheduledRepayment ||
        InstallmentOwnerRole.extraPrincipal ||
        InstallmentOwnerRole.earlySettlement => installmentService
            .revertRepayment(
              RevertRepaymentCommand(transactionId: transaction.id),
            ),
      };
    });
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    if (role == InstallmentOwnerRole.disbursement) {
      return detailVoidOutcomeFromAction(() {
        return installmentService.updateContract(
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
    return detailVoidOutcomeFromAction(() {
      return installmentService.editRepayment(
        EditRepaymentCommand(
          transactionId: transaction.id,
          contractId: contractId,
          note: _nullableStringPatch(value),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    if (role == InstallmentOwnerRole.disbursement) {
      return detailVoidOutcomeFromAction(() {
        return installmentService.updateContract(
          UpdateContractCommand(contractId: contractId, borrowingDate: value),
        );
      });
    }
    return detailVoidOutcomeFromAction(() {
      return installmentService.editRepayment(
        EditRepaymentCommand(
          transactionId: transaction.id,
          contractId: contractId,
          occurredAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    if (role == InstallmentOwnerRole.disbursement) {
      return detailVoidOutcomeFromAction(() {
        return installmentService.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            disbursementAccountId: accountId,
          ),
        );
      });
    }
    return detailVoidOutcomeFromAction(() {
      return installmentService.editRepayment(
        EditRepaymentCommand(
          transactionId: transaction.id,
          contractId: contractId,
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
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注');
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
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注');
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId,
  ) async {
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注');
  }
}
