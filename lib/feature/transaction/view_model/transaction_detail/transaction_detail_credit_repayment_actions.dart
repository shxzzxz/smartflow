part of 'transaction_detail_view_model.dart';

final class _CreditRepaymentActionDispatcher
    implements _TransactionDetailActionDispatcher {
  const _CreditRepaymentActionDispatcher({
    required this.transaction,
    required this.billRepaymentAppService,
    required this.installmentPrepaymentAppService,
    required this.accountRepaymentAppService,
    required this.updateService,
    required this.owner,
  });

  final TransactionReadModel transaction;
  final BillRepaymentAppService billRepaymentAppService;
  final InstallmentPrepaymentAppService installmentPrepaymentAppService;
  final AccountRepaymentAppService accountRepaymentAppService;
  final TransactionUpdateAppService updateService;
  final RepaymentBusinessActivityItem owner;

  String get repaymentId => owner.repaymentId;

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
    switch (owner.repaymentType) {
      case RepaymentType.bill || RepaymentType.installment:
        return bill(billRepaymentAppService);
      case RepaymentType.prepayment:
        return prepayment(installmentPrepaymentAppService);
      case RepaymentType.unattributed:
        return account(accountRepaymentAppService);
    }
  }
}
