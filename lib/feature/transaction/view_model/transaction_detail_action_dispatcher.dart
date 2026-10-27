import 'package:logging/logging.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
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
  AdvanceOrchestrationAppService? advanceAppService,
  AdvanceCaseQueryService? advanceCaseQuery,
}) {
  final ownership = transaction.ownership;
  if (ownership == null) {
    return _DefaultActionDispatcher(
      transaction: transaction,
      editService: editService,
      updateService: updateService,
    );
  }

  if (ownership.ownerType == orchestrationAdvanceOwnerType) {
    if (advanceAppService == null || advanceCaseQuery == null) {
      throw StateError('Advance orchestration services are not configured.');
    }
    return _AdvanceActionDispatcher(
      transaction: transaction,
      advanceAppService: advanceAppService,
      advanceCaseQuery: advanceCaseQuery,
      fallback: _DefaultActionDispatcher(
        transaction: transaction,
        editService: editService,
        updateService: updateService,
      ),
    );
  }

  if (ownership.ownerType == installmentOwnerType) {
    return _InstallmentActionDispatcher(
      transaction: transaction,
      installmentAppService: installmentAppService,
      updateService: updateService,
      contractId: ownership.ownerId,
    );
  }

  if (ownership.ownerType == creditRepaymentOwnerType) {
    return _CreditRepaymentActionDispatcher(
      transaction: transaction,
      repaymentAppService: repaymentAppService,
      updateService: updateService,
      repaymentId: ownership.ownerId,
    );
  }

  return _UnknownActionDispatcher(
    transaction: transaction,
    updateService: updateService,
  );
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

final class _AdvanceActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _AdvanceActionDispatcher({
    required this.transaction,
    required this.advanceAppService,
    required this.advanceCaseQuery,
    required this.fallback,
  });

  final TransactionReadModel transaction;
  final AdvanceOrchestrationAppService advanceAppService;
  final AdvanceCaseQueryService advanceCaseQuery;
  final TransactionDetailActionDispatcher fallback;

  @override
  Future<UiActionOutcome<void>> delete() => fallback.delete();

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) =>
      fallback.changeNote(value);

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) =>
      fallback.changeOccurredAt(value);

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) =>
      fallback.changePostedAt(value);

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  }) async {
    final allocations = singleAllocation(
      accountId: accountId,
      amount: transaction.amountOf(TransactionRole.settlementIn),
    );
    switch (transaction.businessPurpose) {
      case BusinessPurpose.advance:
        final ownership = transaction.ownership;
        final advanceCase = ownership == null
            ? null
            : await advanceCaseQuery.findById(ownership.ownerId);
        if (advanceCase == null) {
          return detailInvalidCommand('无法定位垫付编排实例');
        }
        await advanceAppService.editAdvance(
          EditAdvanceWorkflowCommand(
            transactionId: transaction.id,
            scenario: advanceCase.scenario,
            settlementAllocations: singleAllocation(
              accountId: accountId,
              amount: transaction.primaryAmount,
            ),
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.advanceCollection:
        await advanceAppService.editCollection(
          EditAdvanceCollectionWorkflowCommand(
            transactionId: transaction.id,
            settlementAllocations: allocations,
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.advanceSettlement:
        await advanceAppService.editSettlement(
          EditAdvanceSettlementWorkflowCommand(
            transactionId: transaction.id,
            settlementAllocations: allocations,
          ),
        );
        return const UiActionOutcome.success(null);
      case BusinessPurpose.refund:
        await advanceAppService.editRefund(
          EditAdvanceRefundWorkflowCommand(
            transactionId: transaction.id,
            amount: transaction.primaryAmount,
            categoryAllocations: [
              for (final line in transaction.linesOf(
                TransactionRole.advanceExpenseCategory,
              ))
                if (line.accountId != null)
                  AccountAmountAllocation(
                    accountId: line.accountId!,
                    amount: line.amount,
                  ),
            ],
            settlementAllocations: allocations,
            occurredAt: transaction.occurredAt,
          ),
        );
        return const UiActionOutcome.success(null);
      default:
        return fallback.changeSettlementAccount(
          accountId,
          currentAccountId: currentAccountId,
        );
    }
  }
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
      case BusinessPurpose.advance:
        return detailVoidOutcomeFromAction(() {
          return editService.editAdvance(
            EditAdvanceCommand(
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
      case BusinessPurpose.advanceCollection:
        return detailVoidOutcomeFromAction(
          () => editService.editAdvanceCollection(
            EditAdvanceCollectionCommand(
              transactionId: transaction.id,
              settlementAllocations: singleAllocation(
                accountId: accountId,
                amount: transaction.amountOf(TransactionRole.settlementIn),
              ),
            ),
          ),
        );
      case BusinessPurpose.advanceSettlement:
        return detailVoidOutcomeFromAction(
          () => editService.editAdvanceSettlement(
            EditAdvanceSettlementCommand(
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
