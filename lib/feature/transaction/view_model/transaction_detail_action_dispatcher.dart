import 'package:logging/logging.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart'
    show RepaymentOwnerQuery;
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/error/app_exception.dart';
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
  required DisbursementInstallmentAppService disbursementInstallmentAppService,
  required ConsumptionInstallmentAppService consumptionInstallmentAppService,
  required BillRepaymentAppService billRepaymentAppService,
  required InstallmentPrepaymentAppService installmentPrepaymentAppService,
  required AccountRepaymentAppService accountRepaymentAppService,
  required RepaymentOwnerQuery repaymentOwnerQuery,
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

  if (transaction.businessPurpose == BusinessPurpose.refund &&
      ownership.ownerType == installmentOwnerType) {
    return _InstallmentRefundActionDispatcher(
      transaction: transaction,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
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

  if (ownership.ownerType == orchestrationAmortizationOwnerType) {
    return _AmortizationActionDispatcher(transaction);
  }

  if (ownership.ownerType == installmentOwnerType) {
    return _InstallmentActionDispatcher(
      transaction: transaction,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      updateService: updateService,
      contractId: ownership.ownerId,
    );
  }

  if (ownership.ownerType == creditRepaymentOwnerType) {
    return _CreditRepaymentActionDispatcher(
      transaction: transaction,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
      repaymentOwnerQuery: repaymentOwnerQuery,
      updateService: updateService,
      repaymentId: ownership.ownerId,
    );
  }

  return _UnknownActionDispatcher(
    transaction: transaction,
    updateService: updateService,
  );
}

final class _InstallmentRefundActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _InstallmentRefundActionDispatcher({
    required this.transaction,
    required this.consumptionInstallmentAppService,
  });

  final TransactionReadModel transaction;
  final ConsumptionInstallmentAppService consumptionInstallmentAppService;

  @override
  Future<UiActionOutcome<void>> delete() {
    return detailVoidOutcomeFromAction(
      () => consumptionInstallmentAppService.deleteRefund(
        DeleteConsumptionInstallmentRefundCommand(
          transactionId: transaction.id,
        ),
      ),
    );
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async =>
      detailNotEditable('请在退款编辑页修改备注');

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async =>
      detailNotEditable('请在退款编辑页修改退款时间');

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) {
    final ownership = transaction.ownership;
    final parentTransactionId = transaction.parentTransactionId;
    if (ownership?.ownerType != installmentOwnerType ||
        parentTransactionId == null) {
      return Future.value(detailInvalidCommand('无法定位消费分期退款'));
    }
    return detailVoidOutcomeFromAction(() async {
      await consumptionInstallmentAppService.editRefund(
        EditConsumptionInstallmentRefundCommand(
          transactionId: transaction.id,
          contractId: ownership!.ownerId,
          parentTransactionId: parentTransactionId,
          postedAt: value,
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  }) async => detailNotEditable('请在退款编辑页修改到账分配');
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

final class _AmortizationActionDispatcher
    implements TransactionDetailActionDispatcher {
  const _AmortizationActionDispatcher(this.transaction);

  final TransactionReadModel transaction;

  @override
  Future<UiActionOutcome<void>> delete() async =>
      detailNotEditable('请在摊销计划中终止，不能单独删除计划交易');

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async =>
      detailNotEditable('请在摊销计划中修改备注');

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async =>
      detailNotEditable('摊销计划交易时间由计划控制');

  @override
  Future<UiActionOutcome<void>> changePostedAt(DateTime value) async =>
      detailNotEditable('摊销计划入账时间由计划控制');

  @override
  Future<UiActionOutcome<void>> changeSettlementAccount(
    String accountId, {
    String? currentAccountId,
  }) async => detailNotEditable('摊销计划账户由计划控制');
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
    required this.disbursementInstallmentAppService,
    required this.consumptionInstallmentAppService,
    required this.updateService,
    required this.contractId,
  });

  final TransactionReadModel transaction;
  final InstallmentContractAppService installmentAppService;
  final DisbursementInstallmentAppService disbursementInstallmentAppService;
  final ConsumptionInstallmentAppService consumptionInstallmentAppService;
  final TransactionUpdateAppService updateService;
  final String contractId;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      if (transaction.businessPurpose == BusinessPurpose.dailyExpense) {
        return consumptionInstallmentAppService.delete(
          DeleteInstallmentCommand(contractId: contractId),
        );
      }
      if (transaction.businessPurpose == BusinessPurpose.borrowing) {
        return disbursementInstallmentAppService.delete(
          DeleteInstallmentCommand(contractId: contractId),
        );
      }
      return installmentAppService.deleteContract(
        DeleteContractCommand(contractId: contractId),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    if (transaction.businessPurpose == BusinessPurpose.dailyExpense) {
      return detailVoidOutcomeFromAction(() {
        return updateService.updateBasicInfo(
          UpdateTransactionBasicInfoCommand(
            transactionId: transaction.id,
            note: _nullableStringPatch(value),
          ),
        );
      });
    }
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
    if (transaction.businessPurpose == BusinessPurpose.dailyExpense) {
      return detailNotEditable('消费分期的成交价和结算分配不能直接修改');
    }
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
    required this.billRepaymentAppService,
    required this.installmentPrepaymentAppService,
    required this.accountRepaymentAppService,
    required this.repaymentOwnerQuery,
    required this.updateService,
    required this.repaymentId,
  });

  final TransactionReadModel transaction;
  final BillRepaymentAppService billRepaymentAppService;
  final InstallmentPrepaymentAppService installmentPrepaymentAppService;
  final AccountRepaymentAppService accountRepaymentAppService;
  final RepaymentOwnerQuery repaymentOwnerQuery;
  final TransactionUpdateAppService updateService;
  final String repaymentId;

  @override
  Future<UiActionOutcome<void>> delete() async {
    return detailVoidOutcomeFromAction(() {
      return _dispatch(
        bill: (service) => service.deleteRepayment(
          DeleteCreditRepaymentCommand(repaymentId: repaymentId),
        ),
        prepayment: (service) => service.deleteRepayment(
          DeleteCreditRepaymentCommand(repaymentId: repaymentId),
        ),
        account: (service) => service.deleteRepayment(
          DeleteCreditRepaymentCommand(repaymentId: repaymentId),
        ),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeNote(String? value) async {
    return detailVoidOutcomeFromAction(() {
      final command = EditCreditRepaymentTransactionCommand(
        repaymentId: repaymentId,
        note: _nullableStringPatch(value),
      );
      return _dispatch(
        bill: (service) => service.editRepaymentTransaction(command),
        prepayment: (service) => service.editRepaymentTransaction(command),
        account: (service) => service.editRepaymentTransaction(command),
      );
    });
  }

  @override
  Future<UiActionOutcome<void>> changeOccurredAt(DateTime value) async {
    return detailVoidOutcomeFromAction(() {
      final command = EditCreditRepaymentTransactionCommand(
        repaymentId: repaymentId,
        occurredAt: value,
      );
      return _dispatch(
        bill: (service) => service.editRepaymentTransaction(command),
        prepayment: (service) => service.editRepaymentTransaction(command),
        account: (service) => service.editRepaymentTransaction(command),
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
      final command = EditCreditRepaymentTransactionCommand(
        repaymentId: repaymentId,
        paidFromAccountId: accountId,
      );
      return _dispatch(
        bill: (service) => service.editRepaymentTransaction(command),
        prepayment: (service) => service.editRepaymentTransaction(command),
        account: (service) => service.editRepaymentTransaction(command),
      );
    });
  }

  Future<void> _dispatch({
    required Future<void> Function(BillRepaymentAppService service) bill,
    required Future<void> Function(InstallmentPrepaymentAppService service)
    prepayment,
    required Future<void> Function(AccountRepaymentAppService service) account,
  }) async {
    final type = await repaymentOwnerQuery.findType(repaymentId);
    if (type == null) {
      throw BusinessException(CreditErrorCode.repaymentNotFound);
    }
    switch (type) {
      case RepaymentType.bill || RepaymentType.installment:
        return bill(billRepaymentAppService);
      case RepaymentType.prepayment:
        return prepayment(installmentPrepaymentAppService);
      case RepaymentType.unattributed:
        return account(accountRepaymentAppService);
    }
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
