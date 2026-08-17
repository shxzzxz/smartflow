import 'package:logging/logging.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/patch/patch.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

final _logger = Logger('feature.transaction.detail_action');

abstract interface class TransactionDetailActionDispatcher {
  Future<UiActionOutcome<void>> delete();

  Future<UiActionOutcome<void>> changeNote(String? value);

  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds);

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value);

  Future<UiActionOutcome<void>> changePostedAt(DateTime value);

  Future<UiActionOutcome<void>> changeSettlementAccount(String accountId);
}

TransactionDetailActionDispatcher createTransactionDetailActionDispatcher({
  required Transaction transaction,
  required TransactionEditAppService editService,
  required TransactionUpdateAppService updateService,
  required InstallmentAppService installmentAppService,
  required RepaymentAppService repaymentAppService,
}) {
  final ownership = transaction.ownership;
  if (ownership == null) {
    return _DefaultActionDispatcher(
      transaction: transaction,
      editService: editService,
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

Future<UiActionOutcome<void>> _changeTagsForPlainTransaction({
  required Transaction transaction,
  required TransactionEditAppService editService,
  required Set<String> tagIds,
}) {
  switch (transaction.businessPurpose) {
    case BusinessPurpose.dailyExpense:
      return detailVoidOutcomeFromAction(() {
        return editService.editExpense(
          EditExpenseCommand(transactionId: transaction.id, tagIds: tagIds),
        );
      });
    case BusinessPurpose.dailyIncome:
      return detailVoidOutcomeFromAction(() {
        return editService.editIncome(
          EditIncomeCommand(transactionId: transaction.id, tagIds: tagIds),
        );
      });
    case BusinessPurpose.transfer:
      return detailVoidOutcomeFromAction(() {
        return editService.editTransfer(
          EditTransferCommand(transactionId: transaction.id, tagIds: tagIds),
        );
      });
    case BusinessPurpose.reimbursementAdvance:
      return detailVoidOutcomeFromAction(() {
        return editService.editReimbursementAdvance(
          EditReimbursementAdvanceCommand(
            transactionId: transaction.id,
            tagIds: tagIds,
          ),
        );
      });
    case BusinessPurpose.borrowing:
      return detailVoidOutcomeFromAction(() {
        return editService.editBorrowing(
          EditBorrowingCommand(transactionId: transaction.id, tagIds: tagIds),
        );
      });
    case BusinessPurpose.debtRepayment:
      return detailVoidOutcomeFromAction(() {
        return editService.editRepayment(
          EditRepaymentCommand(transactionId: transaction.id, tagIds: tagIds),
        );
      });
    case BusinessPurpose.refund:
    case BusinessPurpose.reimbursementReceipt:
    case BusinessPurpose.reimbursementClose:
    case BusinessPurpose.openingBalance:
    case BusinessPurpose.balanceAdjustment:
      return Future.value(detailNotEditable(_tagEditDeniedMessage));
  }
}

const String _tagEditDeniedMessage = '当前交易类型不支持修改标签';

Future<UiActionOutcome<void>> _changePostedAt({
  required Transaction transaction,
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

final class _DefaultActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _DefaultActionDispatcher({
    required this.transaction,
    required this.editService,
    required this.updateService,
  });

  final Transaction transaction;
  final TransactionEditAppService editService;
  final TransactionUpdateAppService updateService;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return editService.deleteTransaction(
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
  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds) {
    return _changeTagsForPlainTransaction(
      transaction: transaction,
      editService: editService,
      tagIds: tagIds,
    );
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
    String accountId,
  ) async {
    switch (transaction.businessPurpose) {
      case BusinessPurpose.dailyExpense:
        return detailVoidOutcomeFromAction(() {
          return editService.editExpense(
            EditExpenseCommand(
              transactionId: transaction.id,
              paidFromAccountId: accountId,
            ),
          );
        });
      case BusinessPurpose.dailyIncome:
        return detailVoidOutcomeFromAction(() {
          return editService.editIncome(
            EditIncomeCommand(
              transactionId: transaction.id,
              receiveAccountId: accountId,
            ),
          );
        });
      case BusinessPurpose.reimbursementAdvance:
        return detailVoidOutcomeFromAction(() {
          return editService.editReimbursementAdvance(
            EditReimbursementAdvanceCommand(
              transactionId: transaction.id,
              paidFromAccountId: accountId,
            ),
          );
        });
      case BusinessPurpose.borrowing:
        return detailVoidOutcomeFromAction(() {
          return editService.editBorrowing(
            EditBorrowingCommand(
              transactionId: transaction.id,
              receiveAccountId: accountId,
            ),
          );
        });
      case BusinessPurpose.debtRepayment:
        return detailVoidOutcomeFromAction(() {
          return editService.editRepayment(
            EditRepaymentCommand(
              transactionId: transaction.id,
              paidFromAccountId: accountId,
            ),
          );
        });
      case BusinessPurpose.transfer:
      case BusinessPurpose.refund:
      case BusinessPurpose.reimbursementReceipt:
      case BusinessPurpose.reimbursementClose:
      case BusinessPurpose.openingBalance:
      case BusinessPurpose.balanceAdjustment:
        return detailInvalidCommand('当前交易不支持在详情页修改账户');
    }
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
  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds) {
    return Future.value(detailNotEditable(_tagEditDeniedMessage));
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
    return _changePostedAt(
      transaction: transaction,
      updateService: updateService,
      value: value,
    );
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
  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds) {
    return Future.value(detailNotEditable(_tagEditDeniedMessage));
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
    return _changePostedAt(
      transaction: transaction,
      updateService: updateService,
      value: value,
    );
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
  Future<UiActionOutcome<void>> changeTags(Set<String> tagIds) {
    return Future.value(detailNotEditable(_tagEditDeniedMessage));
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间');
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
    String accountId,
  ) async {
    return detailNotEditable('该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间');
  }
}
