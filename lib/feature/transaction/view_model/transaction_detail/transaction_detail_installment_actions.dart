part of 'transaction_detail_view_model.dart';

final class _InstallmentRefundActionDispatcher
    implements _TransactionDetailActionDispatcher {
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

final class _InstallmentActionDispatcher
    implements _TransactionDetailActionDispatcher {
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
