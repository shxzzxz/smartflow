import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/application/credit/credit_port_api.dart'
    as credit_port;
import 'package:smartflow/application/credit/credit_query_api.dart'
    as credit_query;
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/credit/provider/credit_account_query_providers.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/bill_conversion_installment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/bill_repayment_allocation_view_model.dart';
import 'package:smartflow/feature/credit/view_model/bill_repayment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/installment_repayment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/repayment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/unattributed_repayment_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/refund_form_view_model.dart';
import 'package:smartflow/feature/transaction/view_model/reimbursement_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('repayment form creates repayment command', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(repaymentAppService: repayment);
    final provider = repaymentFormViewModelProvider(
      const RepaymentFormArgs(liabilityAccountId: 'loan'),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final viewModel =
        container.read(provider.notifier)
          ..setPrincipalText('12.34')
          ..setPaidFromAccountId('cash');

    final outcome = await viewModel.submit();

    expect(outcome, isA<SubmitSuccess>());
    expect(
      repayment.liabilityRepaymentCommands.single.principal,
      const Money(minorUnits: 1234),
    );
    expect(
      repayment.liabilityRepaymentCommands.single.liabilityAccountId,
      'loan',
    );
    expect(
      repayment.liabilityRepaymentCommands.single.paidFromAccountId,
      'cash',
    );
  });

  test('repayment form maps business exception to failure', () async {
    final repayment = _FakeRepaymentAppService(
      exception: BusinessException(
        credit.CreditErrorCode.repaymentExceedsAvailable,
        message: '本金超过可还额度',
      ),
    );
    final container = _container(repaymentAppService: repayment);
    final provider = repaymentFormViewModelProvider(
      const RepaymentFormArgs(liabilityAccountId: 'loan'),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final viewModel =
        container.read(provider.notifier)
          ..setPrincipalText('99')
          ..setPaidFromAccountId('cash');

    final outcome = await viewModel.submit();

    expect(outcome, isA<SubmitFailure>());
    expect(
      (outcome as SubmitFailure).error.code,
      credit.CreditErrorCode.repaymentExceedsAvailable.code,
    );
  });

  test(
    'installment prepayment submits through repayment app service',
    () async {
      final repayment = _FakeRepaymentAppService();
      final container = _container(repaymentAppService: repayment);
      final provider = installmentRepaymentFormViewModelProvider(
        const InstallmentRepaymentFormArgs(contractId: 'contract'),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final state = await container.read(provider.future);
      final notifier =
          container.read(provider.notifier)
            ..setPrincipalText('10')
            ..setDiscountText('1');
      final outcome = await notifier.submit();

      expect(state.principalText, '100.00');
      expect(outcome, isA<SubmitSuccess>());
      expect(repayment.prepaymentCommands.single.contractId, 'contract');
      expect(
        repayment.prepaymentCommands.single.principal,
        const Money(minorUnits: 1000),
      );
      expect(
        repayment.prepaymentCommands.single.discount,
        const Money(minorUnits: 100),
      );
      expect(
        repayment.prepaymentCommands.single.transactionInfo!.paidFromAccountId,
        'cash',
      );
    },
  );

  test('bill repayment form submits remaining bill allocation', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(repaymentAppService: repayment);
    final provider = billRepaymentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final state = await container.read(provider.future);
    final outcome = await container.read(provider.notifier).submit();

    expect(state.principalText, '60.00');
    expect(state.interestText, '2.00');
    expect(state.feeText, '1.00');
    expect(outcome, isA<SubmitSuccess>());
    final command = repayment.billRepaymentCommands.single;
    expect(command.billId, 'bill');
    expect(command.transactionInfo!.paidFromAccountId, 'cash');
    expect(command.allocations, hasLength(1));
    expect(command.allocations.single.billItemId, 'bill-item');
    expect(
      command.allocations.single.allocated.principal,
      const Money(minorUnits: 6000),
    );
    expect(
      command.allocations.single.allocated.interest,
      const Money(minorUnits: 200),
    );
    expect(
      command.allocations.single.allocated.fee,
      const Money(minorUnits: 100),
    );
  });

  test('bill repayment form can submit without ledger transaction', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(repaymentAppService: repayment);
    final provider = billRepaymentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.future);
    final outcome =
        await (container.read(provider.notifier)
          ..setCreateTransaction(false)).submit();

    expect(outcome, isA<SubmitSuccess>());
    expect(repayment.billRepaymentCommands.single.transactionInfo, isNull);
  });

  test('bill repayment form supports equal allocation mode', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(
      repaymentAppService: repayment,
      billDetail: _billDetailWithTwoConsumptionItems(),
    );
    final provider = billRepaymentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.future);
    final notifier =
        container.read(provider.notifier)
          ..setPrincipalText('60')
          ..setAllocationMode(BillRepaymentAllocationMode.equal)
          ..calculateAllocation();
    final outcome = await notifier.submit();

    expect(outcome, isA<SubmitSuccess>());
    final allocations = repayment.billRepaymentCommands.single.allocations;
    expect(allocations, hasLength(2));
    expect(allocations[0].billItemId, 'bill-item-1');
    expect(allocations[0].allocated.principal, const Money(minorUnits: 3000));
    expect(allocations[1].billItemId, 'bill-item-2');
    expect(allocations[1].allocated.principal, const Money(minorUnits: 3000));
  });

  test(
    'bill repayment form allows manual edits after calculated allocation',
    () async {
      final repayment = _FakeRepaymentAppService();
      final container = _container(
        repaymentAppService: repayment,
        billDetail: _billDetailWithTwoConsumptionItems(),
      );
      final provider = billRepaymentFormViewModelProvider('bill');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.future);
      final notifier =
          container.read(provider.notifier)
            ..setPrincipalText('60')
            ..setAllocationMode(BillRepaymentAllocationMode.equal)
            ..calculateAllocation()
            ..setManualAllocationText(
              billItemId: 'bill-item-1',
              principalText: '20',
            )
            ..setManualAllocationText(
              billItemId: 'bill-item-2',
              principalText: '40',
            );
      final outcome = await notifier.submit();

      expect(outcome, isA<SubmitSuccess>());
      final allocations = repayment.billRepaymentCommands.single.allocations;
      expect(allocations, hasLength(2));
      expect(allocations[0].billItemId, 'bill-item-1');
      expect(allocations[0].allocated.principal, const Money(minorUnits: 2000));
      expect(allocations[1].billItemId, 'bill-item-2');
      expect(allocations[1].allocated.principal, const Money(minorUnits: 4000));
    },
  );

  test('bill repayment form supports manual allocation mode', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(
      repaymentAppService: repayment,
      billDetail: _billDetailWithTwoConsumptionItems(),
    );
    final provider = billRepaymentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.future);
    final notifier =
        container.read(provider.notifier)
          ..setPrincipalText('60')
          ..setAllocationMode(BillRepaymentAllocationMode.manual)
          ..setManualAllocationText(
            billItemId: 'bill-item-1',
            principalText: '20',
          )
          ..setManualAllocationText(
            billItemId: 'bill-item-2',
            principalText: '40',
          );
    final outcome = await notifier.submit();

    expect(outcome, isA<SubmitSuccess>());
    final allocations = repayment.billRepaymentCommands.single.allocations;
    expect(allocations, hasLength(2));
    expect(allocations[0].billItemId, 'bill-item-1');
    expect(allocations[0].allocated.principal, const Money(minorUnits: 2000));
    expect(allocations[1].billItemId, 'bill-item-2');
    expect(allocations[1].allocated.principal, const Money(minorUnits: 4000));
  });

  test('open bill repayment only allocates consumption items', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(
      repaymentAppService: repayment,
      billDetail: _openBillDetailWithInstallment(),
    );
    final provider = billRepaymentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final state = await container.read(provider.future);
    final outcome = await container.read(provider.notifier).submit();

    expect(state.principalText, '30.00');
    expect(outcome, isA<SubmitSuccess>());
    final command = repayment.billRepaymentCommands.single;
    expect(command.allocations, hasLength(1));
    expect(command.allocations.single.billItemId, 'consumption-item');
    expect(
      command.allocations.single.allocated.principal,
      const Money(minorUnits: 3000),
    );
  });

  test('bill conversion installment form submits repayment command', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(repaymentAppService: repayment);
    final provider = billConversionInstallmentFormViewModelProvider('bill');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final state = await container.read(provider.future);
    final outcome = await container.read(provider.notifier).submit();

    expect(state, isA<BillConversionInstallmentLoaded>());
    expect(outcome, isA<UiActionSuccess<String>>());
    final command = repayment.billConversionCommands.single;
    expect(command.billId, 'bill');
    expect(command.totalPeriods, 12);
    expect(
      command.repaymentMethod,
      credit.InstallmentRepaymentMethod.equalInstallment,
    );
    expect(command.allocations, hasLength(1));
    expect(command.allocations.single.billItemId, 'bill-item');
    expect(
      command.allocations.single.allocated.principal,
      const Money(minorUnits: 6000),
    );
  });

  test('unattributed repayment form submits account repayment', () async {
    final repayment = _FakeRepaymentAppService();
    final container = _container(repaymentAppService: repayment);
    final provider = unattributedRepaymentFormViewModelProvider('loan');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final state = await container.read(provider.future);
    final notifier =
        container.read(provider.notifier)
          ..setInterestText('1')
          ..setFeeText('2')
          ..setDiscountText('0.50');
    final outcome = await notifier.submit();

    expect(state.principalText, '25.00');
    expect(outcome, isA<SubmitSuccess>());
    final command = repayment.unattributedCommands.single;
    expect(command.accountId, 'loan');
    expect(command.amount, const Money(minorUnits: 2500));
    expect(command.interest, const Money(minorUnits: 100));
    expect(command.fee, const Money(minorUnits: 200));
    expect(command.discount, const Money(minorUnits: 50));
    expect(command.transactionInfo!.paidFromAccountId, 'cash');
  });

  test(
    'unattributed repayment form can submit without ledger transaction',
    () async {
      final repayment = _FakeRepaymentAppService();
      final container = _container(repaymentAppService: repayment);
      final provider = unattributedRepaymentFormViewModelProvider('loan');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.future);
      final outcome =
          await (container.read(provider.notifier)
            ..setCreateTransaction(false)).submit();

      expect(outcome, isA<SubmitSuccess>());
      expect(repayment.unattributedCommands.single.transactionInfo, isNull);
    },
  );

  test('refund form submits refund command', () async {
    final posting = _FakePostingService();
    final container = _container(postingService: posting);
    final provider = refundFormViewModelProvider('parent');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final viewModel =
        container.read(provider.notifier)
          ..setAmountText('5')
          ..setRefundToAccountId('cash');

    final outcome = await viewModel.submit();

    expect(outcome, isA<SubmitSuccess>());
    expect(posting.refundCommands.single.parentTransactionId, 'parent');
    expect(posting.refundCommands.single.amount, const Money(minorUnits: 500));
  });

  test('reimbursement close form submits close command', () async {
    final posting = _FakePostingService();
    final container = _container(postingService: posting);
    final provider = reimbursementCloseFormViewModelProvider('parent');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final viewModel =
        container.read(provider.notifier)
          ..setAmountText('8')
          ..setReceiveAccountId('cash');

    final outcome = await viewModel.submit();

    expect(outcome, isA<SubmitSuccess>());
    expect(posting.closeCommands.single.advanceTransactionId, 'parent');
    expect(
      posting.closeCommands.single.actualReceivedAmount,
      const Money(minorUnits: 800),
    );
  });
}

ProviderContainer _container({
  _FakeInstallmentAppService? installmentAppService,
  _FakeRepaymentAppService? repaymentAppService,
  _FakePostingService? postingService,
  credit_query.BillDetailReadModel? billDetail,
  credit_query.CreditAccountOverviewReadModel? creditOverview,
}) {
  final accounts = [
    _account('cash', AccountType.asset),
    _account('loan', AccountType.liability),
    _account('company', AccountType.asset),
  ];
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider.overrideWith(
        (ref, purpose) => Stream.value(switch (purpose) {
          AccountSelectionPurpose.repaymentTarget => [accounts[1]],
          AccountSelectionPurpose.repaymentSource => accounts,
          AccountSelectionPurpose.settlement => [accounts[0]],
          _ => const <Account>[],
        }),
      ),
      accountsByIdProvider.overrideWith(
        (ref) =>
            Stream.value({for (final account in accounts) account.id: account}),
      ),
      transactionDetailProvider.overrideWith(
        (ref, id) => Stream.value(_detail()),
      ),
      billDetailProvider.overrideWith(
        (ref, id) async => billDetail ?? _billDetail(),
      ),
      creditAccountOverviewProvider.overrideWith(
        (ref, id) async => creditOverview ?? _creditOverview(),
      ),
      installmentContractProvider.overrideWith((ref, id) async => _contract()),
      installmentSchedulesProvider.overrideWith(
        (ref, id) async => [_schedule()],
      ),
      installmentRepaymentCashflowsProvider.overrideWith(
        (ref, id) async => const [],
      ),
      installmentContractsByAccountProvider.overrideWith(
        (ref, id) async => const [],
      ),
      installmentAppServiceProvider.overrideWithValue(
        installmentAppService ?? _FakeInstallmentAppService(),
      ),
      repaymentAppServiceProvider.overrideWithValue(
        repaymentAppService ?? _FakeRepaymentAppService(),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(
        postingService ?? _FakePostingService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeInstallmentAppService implements credit.InstallmentAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentAppService implements credit.RepaymentAppService {
  _FakeRepaymentAppService({this.exception});

  final Object? exception;
  final liabilityRepaymentCommands = <credit.CreateLiabilityRepaymentCommand>[];
  final prepaymentCommands =
      <credit.CreateContractPrepaymentRepaymentCommand>[];
  final billRepaymentCommands = <credit.CreateBillRepaymentCommand>[];
  final billConversionCommands =
      <credit.CreateBillConversionInstallmentRepaymentCommand>[];
  final unattributedCommands = <credit.CreateUnattributedRepaymentCommand>[];
  final deleteCommands = <credit.DeleteCreditRepaymentCommand>[];

  @override
  Future<credit_port.CreditLedgerPostedTransaction> createLiabilityRepayment(
    credit.CreateLiabilityRepaymentCommand command,
  ) async {
    liabilityRepaymentCommands.add(command);
    final exception = this.exception;
    if (exception != null) throw exception;
    return const credit_port.CreditLedgerPostedTransaction(
      transactionId: 'transaction',
      rootTransactionId: 'root',
    );
  }

  @override
  Future<credit.CreateRepaymentResult> createBillRepayment(
    credit.CreateBillRepaymentCommand command,
  ) async {
    billRepaymentCommands.add(command);
    return const credit.CreateRepaymentResult(
      repaymentId: 'repayment',
      transactionId: 'transaction',
      rootTransactionId: 'root',
    );
  }

  @override
  Future<credit.CreateRepaymentResult> createBillConversionInstallmentRepayment(
    credit.CreateBillConversionInstallmentRepaymentCommand command,
  ) async {
    billConversionCommands.add(command);
    return const credit.CreateRepaymentResult(
      repaymentId: 'repayment',
      contractId: 'contract',
    );
  }

  @override
  Future<credit.CreateRepaymentResult> createContractPrepaymentRepayment(
    credit.CreateContractPrepaymentRepaymentCommand command,
  ) async {
    prepaymentCommands.add(command);
    return const credit.CreateRepaymentResult(
      repaymentId: 'repayment',
      transactionId: 'transaction',
      rootTransactionId: 'root',
    );
  }

  @override
  Future<credit.CreateRepaymentResult> createUnattributedRepayment(
    credit.CreateUnattributedRepaymentCommand command,
  ) async {
    unattributedCommands.add(command);
    return const credit.CreateRepaymentResult(
      repaymentId: 'repayment',
      transactionId: 'transaction',
      rootTransactionId: 'root',
    );
  }

  @override
  Future<void> deleteRepayment(
    credit.DeleteCreditRepaymentCommand command,
  ) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePostingService implements TransactionPostingAppService {
  final refundCommands = <CreateRefundCommand>[];
  final closeCommands = <CloseReimbursementCommand>[];

  @override
  Future<PostedTransactionResult> createRefund(
    CreateRefundCommand command,
  ) async {
    refundCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> closeReimbursement(
    CloseReimbursementCommand command,
  ) async {
    closeCommands.add(command);
    return _posted();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostedTransactionResult _posted() {
  return const PostedTransactionResult(
    transactionId: 'transaction',
    rootTransactionId: 'root',
  );
}

Account _account(String id, AccountType type) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
}

credit.InstallmentContract _contract() {
  final now = DateTime(2026);
  return credit.InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'loan',
    disbursementAccountId: 'cash',
    sourceType: credit.InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 10000),
    totalPeriods: 10,
    borrowingDate: now,
    firstRepaymentDate: now,
    lastRepaymentDate: now,
    repaymentMethod: credit.InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: credit.InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: credit.InstallmentContractStatus.active,
    createdAt: now,
  );
}

credit.InstallmentSchedule _schedule() {
  final now = DateTime(2026);
  return credit.InstallmentSchedule(
    id: 'schedule',
    contractId: 'contract',
    periodNo: 1,
    expectedRepaymentDate: now,
    expectedPrincipal: const Money(minorUnits: 1000),
    expectedInterest: const Money(minorUnits: 100),
    expectedFee: Money.zero(),
    status: credit.InstallmentScheduleStatus.pending,
    createdAt: now,
  );
}

credit_query.BillDetailReadModel _billDetail() {
  final period = credit_query.BillPeriod(year: 2026, month: 6);
  final allocated = credit_query.RepaymentAmountBreakdown(
    principal: const Money(minorUnits: 4000),
    interest: const Money(minorUnits: 100),
    fee: Money.zero(),
    discount: Money.zero(),
  );
  return credit_query.BillDetailReadModel(
    summary: credit_query.BillSummaryReadModel(
      id: 'bill',
      accountId: 'loan',
      period: period,
      status: credit_query.BillStatus.billed,
      expectedPrincipal: const Money(minorUnits: 10000),
      expectedInterest: const Money(minorUnits: 300),
      expectedFee: const Money(minorUnits: 100),
      pendingPrincipal: const Money(minorUnits: 6000),
      itemCount: 1,
      overdueItemCount: 0,
      dueDate: DateTime(2026, 6, 20),
    ),
    items: [
      credit_query.BillItemReadModel(
        id: 'bill-item',
        itemType: credit_query.BillItemType.consumption,
        label: '消费',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 10000),
        expectedInterest: const Money(minorUnits: 300),
        expectedFee: const Money(minorUnits: 100),
        allocated: allocated,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}

credit_query.BillDetailReadModel _billDetailWithTwoConsumptionItems() {
  final period = credit_query.BillPeriod(year: 2026, month: 6);
  final summary = credit_query.BillSummaryReadModel(
    id: 'bill',
    accountId: 'loan',
    period: period,
    status: credit_query.BillStatus.billed,
    expectedPrincipal: const Money(minorUnits: 10000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: const Money(minorUnits: 10000),
    itemCount: 2,
    overdueItemCount: 0,
  );
  return credit_query.BillDetailReadModel(
    summary: summary,
    items: [
      credit_query.BillItemReadModel(
        id: 'bill-item-1',
        itemType: credit_query.BillItemType.consumption,
        label: '消费',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 5000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
      credit_query.BillItemReadModel(
        id: 'bill-item-2',
        itemType: credit_query.BillItemType.consumption,
        label: '消费',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 5000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}

credit_query.BillDetailReadModel _openBillDetailWithInstallment() {
  final period = credit_query.BillPeriod(year: 2026, month: 6);
  final summary = credit_query.BillSummaryReadModel(
    id: 'bill',
    accountId: 'loan',
    period: period,
    status: credit_query.BillStatus.open,
    expectedPrincipal: const Money(minorUnits: 8000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: const Money(minorUnits: 8000),
    itemCount: 2,
    overdueItemCount: 0,
  );
  return credit_query.BillDetailReadModel(
    summary: summary,
    items: [
      credit_query.BillItemReadModel(
        id: 'installment-item',
        itemType: credit_query.BillItemType.installment,
        label: '现金分期',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 5000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
      credit_query.BillItemReadModel(
        id: 'consumption-item',
        itemType: credit_query.BillItemType.consumption,
        label: '消费',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 3000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}

credit_query.CreditAccountOverviewReadModel _creditOverview() {
  return credit_query.CreditAccountOverviewReadModel(
    creditAccount: credit_query.CreditLiabilityAccount(
      id: 'credit-extension',
      accountId: 'loan',
      kind: credit_query.CreditLiabilityAccountKind.credit,
      billingDayToNext: true,
      creditLimit: const Money(minorUnits: 100000),
      billingDay: 5,
      repaymentDay: 25,
    ),
    liabilityBalance: const Money(minorUnits: 2500),
    availableCredit: const Money(minorUnits: 97500),
    buckets: const credit_query.CreditDebtBuckets(
      billDebt: Money(minorUnits: 0),
      futureContractDebt: Money(minorUnits: 0),
      unattributedDebt: Money(minorUnits: 2500),
    ),
    unattributedRepayments: const [],
  );
}

TransactionDetail _detail() {
  final transaction = Transaction(
    id: 'parent',
    rootTransactionId: 'parent',
    businessPurpose: BusinessPurpose.reimbursementAdvance,
    occurredAt: DateTime(2026),
    primaryAmount: const Money(minorUnits: 1000),
    mutationKind: MutationKind.original,
    businessState: BusinessState.current,
    sourceKind: SourceKind.manual,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    reimbursementExpenseAccountId: 'expense',
    details: const [],
    entries: [
      Entry(
        id: 'entry-1',
        transactionId: 'parent',
        accountId: 'company',
        direction: EntryDirection.debit,
        amount: const Money(minorUnits: 1000),
      ),
      Entry(
        id: 'entry-2',
        transactionId: 'parent',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: const Money(minorUnits: 1000),
      ),
    ],
  );
  return TransactionDetail(
    transaction: transaction,
    createdAt: DateTime(2026),
    entries: transaction.entries,
    details: const <TransactionDetailRecord>[],
    refundedTotal: const Money(minorUnits: 200),
    reimbursementSummary: const ReimbursementSummary(
      advanceAmount: Money(minorUnits: 1000),
      receivedAmount: Money(minorUnits: 200),
      outstanding: Money(minorUnits: 800),
      isClosed: false,
    ),
  );
}
