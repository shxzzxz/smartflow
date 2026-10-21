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

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value);

  Future<UiActionOutcome<void>> changePostedAt(DateTime value);

  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  });
}

TransactionDetailActionDispatcher createTransactionDetailActionDispatcher({
  required TransactionReadModel transaction,
  required TransactionEditAppService editService,
  required TransactionUpdateAppService updateService,
  required InstallmentContractAppService installmentAppService,
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

final class _DefaultActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _DefaultActionDispatcher({
    required this.transaction,
    required this.editService,
    required this.updateService,
  });

  final TransactionReadModel transaction;
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
  }) async {
    switch (transaction.businessPurpose) {
      case BusinessPurpose.dailyExpense:
        return detailVoidOutcomeFromAction(() {
          return editService.editExpense(
            EditExpenseCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.primaryAmount,
              ),
            ),
          );
        });
      case BusinessPurpose.dailyIncome:
        return detailVoidOutcomeFromAction(() {
          return editService.editIncome(
            EditIncomeCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.primaryAmount,
              ),
            ),
          );
        });
      case BusinessPurpose.reimbursementAdvance:
        return detailVoidOutcomeFromAction(() {
          return editService.editReimbursementAdvance(
            EditReimbursementAdvanceCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.primaryAmount,
              ),
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
      case BusinessPurpose.lending:
        return detailVoidOutcomeFromAction(
          () =>
              (editService as ReceivableTransactionEditAppService).editLending(
                EditLendingCommand(
                  transactionId: transaction.id,
                  paidFromAccountId: accountId,
                ),
              ),
        );
      case BusinessPurpose.receivableCollection:
        return detailVoidOutcomeFromAction(
          () => (editService as ReceivableTransactionEditAppService)
              .editReceivableCollection(
                EditReceivableCollectionCommand(
                  transactionId: transaction.id,
                  receiveAccountId: accountId,
                ),
              ),
        );
      case BusinessPurpose.transfer:
        final from = transaction.accountOf(TransactionRole.settlementOut);
        final to = transaction.accountOf(TransactionRole.settlementIn);
        if (currentAccountId != from && currentAccountId != to) {
          return detailInvalidCommand('无法确定要修改的转账账户');
        }
        return detailVoidOutcomeFromAction(
          () => editService.editTransfer(
            EditTransferCommand(
              transactionId: transaction.id,
              fromAccountId: currentAccountId == from ? accountId : null,
              toAccountId: currentAccountId == to ? accountId : null,
            ),
          ),
        );
      case BusinessPurpose.refund:
        return detailVoidOutcomeFromAction(
          () => editService.editRefund(
            EditRefundCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.amountOf(TransactionRole.settlementIn),
              ),
            ),
          ),
        );
      case BusinessPurpose.reimbursementReceipt:
        return detailVoidOutcomeFromAction(
          () => editService.editReimbursementReceipt(
            EditReimbursementReceiptCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.amountOf(TransactionRole.settlementIn),
              ),
            ),
          ),
        );
      case BusinessPurpose.reimbursementClose:
        return detailVoidOutcomeFromAction(
          () => editService.editReimbursementClose(
            EditReimbursementCloseCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.amountOf(TransactionRole.settlementIn),
              ),
            ),
          ),
        );
      case BusinessPurpose.openingBalance:
      case BusinessPurpose.balanceAdjustment:
      case BusinessPurpose.badDebt:
      case BusinessPurpose.debtRelief:
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

  final TransactionReadModel transaction;
  final InstallmentContractAppService installmentAppService;
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
      return installmentAppService.updateContractDetails(
        UpdateContractDetailsCommand(
          contractId: contractId,
          note: value == null
              ? const Patch<String>.clear()
              : Patch<String>.set(value),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.updateContractDetails(
        UpdateContractDetailsCommand(
          contractId: contractId,
          borrowingDate: value,
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
  }) async {
    return detailVoidOutcomeFromAction(() {
      return installmentAppService.updateContractDetails(
        UpdateContractDetailsCommand(
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

  final TransactionReadModel transaction;
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
  }) async {
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

  final TransactionReadModel transaction;
  final TransactionUpdateAppService updateService;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailNotEditable('未识别的业务来源不支持此操作');
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
    return detailNotEditable('未识别的业务来源不支持此操作');
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
  }) async {
    return detailNotEditable('未识别的业务来源不支持此操作');
  }
}
