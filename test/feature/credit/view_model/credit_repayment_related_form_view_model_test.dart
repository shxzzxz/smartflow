import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/installment_repayment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/installment_repayment_mode.dart';
import 'package:smartflow/feature/credit/view_model/repayment_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/refund_form_view_model.dart';
import 'package:smartflow/feature/transaction/view_model/reimbursement_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('repayment form creates repayment command', () async {
    final creditSvc = _FakeCreditService();
    final container = _container(creditService: creditSvc);
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
      creditSvc.createRepaymentCommands.single.principal,
      const Money(minorUnits: 1234),
    );
    expect(creditSvc.createRepaymentCommands.single.liabilityAccountId, 'loan');
    expect(creditSvc.createRepaymentCommands.single.paidFromAccountId, 'cash');
  });

  test('repayment form maps business exception to failure', () async {
    final creditSvc = _FakeCreditService(
      exception: BusinessException(
        credit.CreditErrorCode.repaymentExceedsAvailable,
        message: '本金超过可还额度',
      ),
    );
    final container = _container(creditService: creditSvc);
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
    'installment extra principal repayment submits through repayment service',
    () async {
      final repayment = _FakeRepaymentService();
      final container = _container(repaymentService: repayment);
      final provider = installmentRepaymentFormViewModelProvider(
        const InstallmentRepaymentFormArgs(
          contractId: 'contract',
          mode: InstallmentRepaymentMode.extraPrincipal,
        ),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final state = await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..setPrincipalText('10');
      final outcome = await notifier.submit();

      expect(state.principalText, '');
      expect(outcome, isA<SubmitSuccess>());
      expect(repayment.extraPrincipalCommands.single.contractId, 'contract');
      expect(
        repayment.extraPrincipalCommands.single.principal,
        const Money(minorUnits: 1000),
      );
      expect(
        repayment
            .extraPrincipalCommands
            .single
            .transactionInfo!
            .paidFromAccountId,
        'cash',
      );
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
  _FakeCreditService? creditService,
  _FakeInstallmentService? installmentService,
  _FakeRepaymentService? repaymentService,
  _FakePostingService? postingService,
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
      creditServiceProvider.overrideWithValue(
        creditService ?? _FakeCreditService(),
      ),
      installmentServiceProvider.overrideWithValue(
        installmentService ?? _FakeInstallmentService(),
      ),
      repaymentServiceProvider.overrideWithValue(
        repaymentService ?? _FakeRepaymentService(),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(
        postingService ?? _FakePostingService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCreditService implements credit.CreditService {
  _FakeCreditService({this.exception});

  final Object? exception;
  final createRepaymentCommands = <credit.CreateRepaymentCommand>[];

  @override
  Future<PostedTransactionResult> createRepayment(
    credit.CreateRepaymentCommand command,
  ) async {
    createRepaymentCommands.add(command);
    final exception = this.exception;
    if (exception != null) throw exception;
    return _posted();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInstallmentService implements credit.InstallmentService {
  final scheduledCommands = <credit.CreateScheduledRepaymentCommand>[];

  @override
  Future<PostedTransactionResult> createScheduledRepayment(
    credit.CreateScheduledRepaymentCommand command,
  ) async {
    scheduledCommands.add(command);
    return _posted();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentService implements credit.RepaymentService {
  final extraPrincipalCommands =
      <credit.CreateExtraPrincipalRepaymentCommand>[];

  @override
  Future<credit.CreateRepaymentResult> createExtraPrincipalRepayment(
    credit.CreateExtraPrincipalRepaymentCommand command,
  ) async {
    extraPrincipalCommands.add(command);
    return const credit.CreateRepaymentResult(
      repaymentId: 'repayment',
      transactionId: 'transaction',
      rootTransactionId: 'root',
    );
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
