part of 'transaction_detail_view_model.dart';

final _actionLogger = Logger('feature.transaction.detail_action');

abstract interface class _TransactionDetailActionDispatcher {
  Future<UiActionOutcome<void>> delete();

  Future<UiActionOutcome<void>> changeNote(String? value);

  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value);

  Future<UiActionOutcome<void>> changePostedAt(DateTime value);

  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  });
}

_TransactionDetailActionDispatcher _createTransactionDetailActionDispatcher({
  required TransactionDetailContext context,
  required TransactionEditAppService editService,
  required TransactionUpdateAppService updateService,
  required InstallmentContractAppService installmentAppService,
  required DisbursementInstallmentAppService disbursementInstallmentAppService,
  required ConsumptionInstallmentAppService consumptionInstallmentAppService,
  required BillRepaymentAppService billRepaymentAppService,
  required InstallmentPrepaymentAppService installmentPrepaymentAppService,
  required AccountRepaymentAppService accountRepaymentAppService,
  AdvanceOrchestrationAppService? advanceAppService,
}) {
  final transaction = context.transaction;
  final owner = context.owner;
  if (owner == null) {
    return _DefaultActionDispatcher(
      transaction: transaction,
      editService: editService,
      updateService: updateService,
    );
  }

  if (transaction.businessPurpose == BusinessPurpose.refund &&
      owner is InstallmentTransactionDetailOwnerContext) {
    return _InstallmentRefundActionDispatcher(
      transaction: transaction,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
    );
  }

  if (owner is AdvanceTransactionDetailOwnerContext) {
    if (advanceAppService == null) {
      throw StateError('Advance orchestration services are not configured.');
    }
    return _AdvanceActionDispatcher(
      transaction: transaction,
      owner: owner,
      advanceAppService: advanceAppService,
      fallback: _DefaultActionDispatcher(
        transaction: transaction,
        editService: editService,
        updateService: updateService,
      ),
    );
  }

  if (owner is AmortizationTransactionDetailOwnerContext) {
    return _AmortizationActionDispatcher(
      transaction,
      updateService: updateService,
    );
  }

  if (owner is InstallmentTransactionDetailOwnerContext) {
    return _InstallmentActionDispatcher(
      transaction: transaction,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      updateService: updateService,
      contractId: owner.ownerId,
    );
  }

  if (owner is RepaymentTransactionDetailOwnerContext) {
    return _CreditRepaymentActionDispatcher(
      transaction: transaction,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
      updateService: updateService,
      owner: owner,
    );
  }

  return _UnknownActionDispatcher(
    transaction: transaction,
    updateService: updateService,
  );
}

final class _DefaultActionDispatcher
    implements _TransactionDetailActionDispatcher {
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
              outgoingAllocations: currentAccountId == from
                  ? singleAllocation(
                      accountId: accountId,
                      amount: transaction.primaryAmount,
                    )
                  : null,
              incomingAllocations: currentAccountId == to
                  ? singleAllocation(
                      accountId: accountId,
                      amount: transaction.primaryAmount,
                    )
                  : null,
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

final class _UnknownActionDispatcher
    implements _TransactionDetailActionDispatcher {
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
