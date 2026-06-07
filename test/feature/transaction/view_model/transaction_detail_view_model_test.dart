import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart'
    hide CorrectRepaymentCommand, CreateRepaymentCommand;
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_view_model.dart';
import 'package:smartflow/widget/business/account_lookup.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

void main() {
  group('TransactionDetailViewModel', () {
    test('derives dynamic state for daily expense', () async {
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        entries: [
          _entry('cash', EntryDirection.credit),
          _entry('food', EntryDirection.debit),
        ],
        refundedTotal: const Money(minorUnits: 500),
      );
      final container = _container(detail: detail);

      final state = await _readState(container);

      final loaded = state as TransactionDetailLoaded;
      expect(loaded.behavior.bannerText, isNull);
      expect(loaded.hero.title, '午餐');
      expect(loaded.hero.iconKey, 'meal');
      expect(loaded.refund?.hasRefund, true);
      expect(loaded.showExcludeStats, true);
      expect(loaded.showExcludeBudget, true);
      expect(loaded.actionButtons.map((button) => button.kind), [
        DetailActionKind.refund,
        DetailActionKind.edit,
      ]);
      final accountRow = loaded.accountRows.singleWhere(
        (row) => row.label == '收支账户',
      );
      expect(accountRow.permission, isA<DetailEditDenied>());
    });

    test(
      'dispatches installment repayment account change to credit service',
      () async {
        final installment = _FakeInstallmentService();
        final detail = _detail(
          purpose: BusinessPurpose.debtRepayment,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
            ownerRole: 'scheduled_repayment',
          ),
          entries: [
            _entry('cash', EntryDirection.credit),
            _entry('loan', EntryDirection.debit),
          ],
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountUsage.settlement, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = installment.editRepaymentCommands.single;
        expect(command.transactionId, 'tx-1');
        expect(command.contractId, 'contract-1');
        expect(command.paidFromAccountId, 'bank');
      },
    );

    test(
      'maps installment disbursement update exception to action failure',
      () async {
        final installment = _FakeInstallmentService(
          updateContractException: BusinessException(
            CreditErrorCode.contractPersistenceConflict,
            message: '合同数据已变化，请刷新后重试。',
          ),
        );
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
            ownerRole: 'disbursement',
          ),
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeNote('new note');

        expect(outcome, isA<UiActionFailure<void>>());
        final failure = outcome as UiActionFailure<void>;
        expect(
          failure.error.code,
          CreditErrorCode.contractPersistenceConflict.code,
        );
        expect(failure.error.message, '合同数据已变化，请刷新后重试。');
      },
    );

    test(
      'maps installment disbursement regular exception to unknown failure',
      () async {
        final installment = _FakeInstallmentService(
          updateContractException: Exception('database failed'),
        );
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
            ownerRole: 'disbursement',
          ),
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeNote('new note');

        expect(outcome, isA<UiActionFailure<void>>());
        final failure = outcome as UiActionFailure<void>;
        expect(failure.error.code, 'unknown');
        expect(failure.error.message, '未知错误，请稍后重试。');
      },
    );

    test('maps update exception to UI action failure', () async {
      final update = _FakeTransactionUpdateAppService(
        reportingFlagException: BusinessException(
          LedgerErrorCode.transactionNotEditable,
          message: '交易当前不可编辑',
        ),
      );
      final container = _container(
        detail: _detail(purpose: BusinessPurpose.dailyIncome),
        update: update,
      );
      await _readState(container);

      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .toggleExcludeStats(true);

      expect(outcome, isA<UiActionFailure<void>>());
      final failure = outcome as UiActionFailure<void>;
      expect(failure.error.code, LedgerErrorCode.transactionNotEditable.code);
      expect(failure.error.message, '交易当前不可编辑');
    });

    test('submits reimbursement close command', () async {
      final posting = _FakeTransactionPostingAppService();
      final detail = _detail(
        purpose: BusinessPurpose.reimbursementAdvance,
        entries: [
          _entry('cash', EntryDirection.credit),
          _entry('company', EntryDirection.debit),
          _entry('food', EntryDirection.debit),
        ],
        reimbursementSummary: const ReimbursementSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 3000),
          outstanding: Money(minorUnits: 7000),
          isClosed: false,
        ),
      );
      final container = _container(detail: detail, posting: posting);
      await _readState(container);

      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .submitReimbursement(
            ReimbursementSubmitInput(
              amount: const Money(minorUnits: 7000),
              receiveAccountId: 'bank',
              occurredAt: DateTime(2026, 1, 2, 9),
              closeReimbursement: true,
              noteText: ' done ',
            ),
          );

      expect(outcome, isA<UiActionSuccess<void>>());
      final command = posting.closeCommands.single;
      expect(command.advanceTransactionId, 'tx-1');
      expect(command.receivableAccountId, 'company');
      expect(command.receiveAccountId, 'bank');
      expect(command.actualReceivedAmount, const Money(minorUnits: 7000));
      expect(command.note, 'done');
    });

    test('unknown owner only allows note edit', () async {
      final update = _FakeTransactionUpdateAppService();
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        ownership: const TransactionOwnership(ownerType: 'unknown-owner'),
      );
      final container = _container(detail: detail, update: update);

      final state = await _readState(container);
      final loaded = state as TransactionDetailLoaded;
      expect(loaded.behavior.bannerText, contains('unknown-owner'));
      expect(loaded.showExcludeStats, false);
      final editAction = loaded.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(editAction.enabled, false);

      final accountOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeAccount(AccountUsage.settlement, 'bank');
      expect(accountOutcome, isA<UiActionFailure<void>>());

      final noteOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeNote('new note');
      expect(noteOutcome, isA<UiActionSuccess<void>>());
      expect(update.basicInfoCommands.single.note, isNotNull);
    });
  });
}

ProviderContainer _container({
  required TransactionDetail detail,
  _FakeTransactionUpdateAppService? update,
  _FakeTransactionCorrectionAppService? correction,
  _FakeTransactionPostingAppService? posting,
  _FakeInstallmentService? installment,
}) {
  final accounts = <String, Account>{
    'cash': _account('cash', '现金', iconKey: 'cash'),
    'bank': _account('bank', '银行卡', iconKey: 'account'),
    'company': _account(
      'company',
      '公司报销',
      subtype: AccountSubtype.reimbursement,
      iconKey: 'reimburse',
    ),
    'loan': _account('loan', '贷款', type: AccountType.liability),
    'food': _account('food', '午餐', type: AccountType.expense, iconKey: 'meal'),
  };
  final container = ProviderContainer(
    overrides: [
      transactionDetailProvider(
        'tx-1',
      ).overrideWith((ref) => Stream.value(detail)),
      accountLookupProvider.overrideWith(
        (ref) => Stream.value(AccountLookup(accounts)),
      ),
      accountsForUsageProvider(AccountUsage.settlement).overrideWith(
        (ref) => Stream.value([accounts['cash']!, accounts['bank']!]),
      ),
      accountsForUsageProvider(
        AccountUsage.reimbursement,
      ).overrideWith((ref) => Stream.value([accounts['company']!])),
      transactionUpdateAppServiceProvider.overrideWithValue(
        update ?? _FakeTransactionUpdateAppService(),
      ),
      transactionCorrectionAppServiceProvider.overrideWithValue(
        correction ?? _FakeTransactionCorrectionAppService(),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(
        posting ?? _FakeTransactionPostingAppService(),
      ),
      installmentServiceProvider.overrideWithValue(
        installment ?? _FakeInstallmentService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<TransactionDetailUiState> _readState(ProviderContainer container) {
  final subscription = container.listen(
    transactionDetailViewModelProvider('tx-1'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(transactionDetailViewModelProvider('tx-1').future);
}

TransactionDetail _detail({
  BusinessPurpose purpose = BusinessPurpose.dailyExpense,
  TransactionOwnership? ownership,
  List<Entry>? entries,
  Money? refundedTotal,
  ReimbursementSummary? reimbursementSummary,
}) {
  return TransactionDetail(
    transaction: Transaction(
      id: 'tx-1',
      rootTransactionId: 'tx-1',
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      mutationKind: MutationKind.original,
      businessState: BusinessState.current,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: ownership,
      reimbursementExpenseAccountId:
          purpose == BusinessPurpose.reimbursementAdvance ? 'food' : null,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    details: const [],
    entries:
        entries ??
        [
          _entry('cash', EntryDirection.credit),
          _entry('food', EntryDirection.debit),
        ],
    refundedTotal: refundedTotal,
    reimbursementSummary: reimbursementSummary,
  );
}

Entry _entry(String accountId, EntryDirection direction) {
  return Entry(
    id: 'entry-$accountId-$direction',
    transactionId: 'tx-1',
    accountId: accountId,
    direction: direction,
    amount: const Money(minorUnits: 10000),
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  AccountSubtype? subtype,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    subtype: subtype,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}

PostedTransactionResult _posted() {
  return const PostedTransactionResult(
    transactionId: 'tx-1',
    rootTransactionId: 'tx-1',
  );
}

class _FakeTransactionUpdateAppService implements TransactionUpdateAppService {
  _FakeTransactionUpdateAppService({this.reportingFlagException});

  final Object? reportingFlagException;
  final basicInfoCommands = <UpdateTransactionBasicInfoCommand>[];
  final reportingFlagCommands = <UpdateTransactionReportingFlagCommand>[];

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) async {
    reportingFlagCommands.add(command);
    final exception = reportingFlagException;
    if (exception != null) throw exception;
    return _posted();
  }

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeTransactionCorrectionAppService
    implements TransactionCorrectionAppService {
  final canceledTransactionIds = <String>[];
  final reimbursementAdvanceCommands = <CorrectReimbursementAdvanceCommand>[];

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    canceledTransactionIds.add(command.transactionId);
  }

  @override
  Future<PostedTransactionResult> correctReimbursementAdvance(
    CorrectReimbursementAdvanceCommand command,
  ) async {
    reimbursementAdvanceCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> correctBorrowing(
    CorrectBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctExpense(
    CorrectExpenseCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctIncome(CorrectIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctRefund(CorrectRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctReimbursementClose(
    CorrectReimbursementCloseCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctReimbursementReceipt(
    CorrectReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctRepayment(
    CorrectRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> correctTransfer(
    CorrectTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  final receiptCommands = <CreateReimbursementReceiptCommand>[];
  final closeCommands = <CloseReimbursementCommand>[];

  @override
  Future<PostedTransactionResult> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) async {
    receiptCommands.add(command);
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
  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createExpense(CreateExpenseCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRefund(CreateRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createIncome(CreateIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeInstallmentService implements InstallmentService {
  _FakeInstallmentService({this.updateContractException});

  final Object? updateContractException;
  final updateContractCommands = <UpdateContractCommand>[];
  final editRepaymentCommands = <EditRepaymentCommand>[];
  final deleteContractCommands = <DeleteContractCommand>[];
  final revertRepaymentCommands = <RevertRepaymentCommand>[];

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    updateContractCommands.add(command);
    final exception = updateContractException;
    if (exception != null) throw exception;
  }

  @override
  Future<void> editRepayment(EditRepaymentCommand command) async {
    editRepaymentCommands.add(command);
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    deleteContractCommands.add(command);
  }

  @override
  Future<void> revertRepayment(RevertRepaymentCommand command) async {
    revertRepaymentCommands.add(command);
  }

  @override
  Future<CreateContractResult> createBillConversionContract(
    CreateBillConversionContractCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createEarlySettlement(
    CreateEarlySettlementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createPrincipalPrepayment(
    CreatePrincipalPrepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createScheduledRepayment(
    CreateScheduledRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<InstallmentContract?> findContract(String contractId) {
    throw UnimplementedError();
  }

  @override
  Future<InstallmentLink?> findLinkByTransaction(String transactionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<InstallmentRepayment>> listRepayments(String contractId) {
    throw UnimplementedError();
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) {
    throw UnimplementedError();
  }

  @override
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId) {
    throw UnimplementedError();
  }
}
