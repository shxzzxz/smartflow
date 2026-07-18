import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_view_model.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

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
      expect(accountRow.permission, isA<DetailEditAllowed>());
    });

    test(
      'dispatches plain expense account change to ledger edit service',
      () async {
        final editService = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(purpose: BusinessPurpose.dailyExpense),
          editService: editService,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.settlement, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = editService.expenseCommands.single;
        expect(command.transactionId, 'tx-1');
        expect(command.paidFromAccountId, 'bank');
      },
    );

    test(
      'dispatches plain income account change to ledger edit service',
      () async {
        final editService = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.dailyIncome,
            entries: [
              _entry('cash', EntryDirection.debit),
              _entry('salary', EntryDirection.credit),
            ],
          ),
          editService: editService,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.settlement, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = editService.incomeCommands.single;
        expect(command.transactionId, 'tx-1');
        expect(command.receiveAccountId, 'bank');
      },
    );

    test(
      'dispatches installment disbursement account change to credit app service',
      () async {
        final installment = _FakeInstallmentAppService();
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
            ownerRole: 'disbursement',
          ),
          entries: [
            _entry('loan', EntryDirection.credit),
            _entry('cash', EntryDirection.debit),
          ],
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.repaymentSource, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = installment.updateContractCommands.single;
        expect(command.contractId, 'contract-1');
        expect(command.disbursementAccountId, 'bank');
      },
    );

    test(
      'maps installment disbursement update exception to action failure',
      () async {
        final installment = _FakeInstallmentAppService(
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
      'routes credit repayment owner edits and delete to repayment app service',
      () async {
        final repayment = _FakeRepaymentAppService();
        final detail = _detail(
          purpose: BusinessPurpose.debtRepayment,
          ownership: const TransactionOwnership(
            ownerType: creditRepaymentOwnerType,
            ownerId: 'repayment-1',
            ownerRole: 'BILL',
          ),
          entries: [
            _entry('cash', EntryDirection.credit),
            _entry('loan', EntryDirection.debit),
          ],
        );
        final container = _container(detail: detail, repayment: repayment);

        final state = await _readState(container);
        final loaded = state as TransactionDetailLoaded;
        expect(loaded.behavior.bannerText, contains('金额调整请在信贷页面处理'));
        expect(loaded.behavior.editRoute, '/repayments/repayment-1/edit');
        expect(loaded.behavior.canEditOccurredAt, isA<DetailEditAllowed>());
        expect(loaded.behavior.canEditNote, isA<DetailEditAllowed>());
        final accountRow = loaded.accountRows.singleWhere(
          (row) => row.label == '还款账户',
        );
        expect(accountRow.permission, isA<DetailEditAllowed>());

        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.changeOccurredAt(DateTime(2026, 2, 1)),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.changeNote(' repayment note '),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.changeAccount(
            AccountSelectionPurpose.repaymentSource,
            'bank',
          ),
          isA<UiActionSuccess<void>>(),
        );
        expect(await notifier.delete(), isA<UiActionSuccess<void>>());

        expect(repayment.editCommands, hasLength(3));
        expect(repayment.editCommands[0].repaymentId, 'repayment-1');
        expect(repayment.editCommands[0].occurredAt, DateTime(2026, 2, 1));
        expect(
          (repayment.editCommands[1].note as PatchSet<String?>).value,
          'repayment note',
        );
        expect(repayment.editCommands[2].paidFromAccountId, 'bank');
        expect(repayment.deleteCommands.single.repaymentId, 'repayment-1');
      },
    );

    test(
      'maps installment disbursement regular exception to unknown failure',
      () async {
        final installment = _FakeInstallmentAppService(
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

    test('updates posted time through the ledger basic info service', () async {
      final update = _FakeTransactionUpdateAppService();
      final container = _container(
        detail: _detail(purpose: BusinessPurpose.dailyExpense),
        update: update,
      );
      await _readState(container);

      final postedAt = DateTime(2026, 2, 3, 10);
      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changePostedAt(postedAt);

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(update.basicInfoCommands.single.postedAt, postedAt);
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

    test('unknown owner still allows note and posted time edits', () async {
      final update = _FakeTransactionUpdateAppService();
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        ownership: const TransactionOwnership(ownerType: 'unknown-owner'),
      );
      final container = _container(detail: detail, update: update);

      final state = await _readState(container);
      final loaded = state as TransactionDetailLoaded;
      expect(loaded.behavior.bannerText, contains('unknown-owner'));
      expect(loaded.behavior.canEditPostedAt, isA<DetailEditAllowed>());
      expect(loaded.showExcludeStats, false);
      final editAction = loaded.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(editAction.enabled, false);

      final accountOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeAccount(AccountSelectionPurpose.settlement, 'bank');
      expect(accountOutcome, isA<UiActionFailure<void>>());

      final noteOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeNote('new note');
      expect(noteOutcome, isA<UiActionSuccess<void>>());
      final postedOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changePostedAt(DateTime(2026, 3, 1));
      expect(postedOutcome, isA<UiActionSuccess<void>>());
      expect(update.basicInfoCommands.first.note, isNotNull);
      expect(update.basicInfoCommands.last.postedAt, DateTime(2026, 3, 1));
    });
  });
}

ProviderContainer _container({
  required TransactionDetail detail,
  _FakeTransactionUpdateAppService? update,
  _FakeTransactionEditAppService? editService,
  _FakeTransactionPostingAppService? posting,
  _FakeInstallmentAppService? installment,
  _FakeRepaymentAppService? repayment,
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
    'salary': _account('salary', '工资', type: AccountType.income),
  };
  final container = ProviderContainer(
    overrides: [
      transactionDetailProvider(
        'tx-1',
      ).overrideWith((ref) => Stream.value(detail)),
      accountLookupProvider.overrideWith(
        (ref) => Stream.value(AccountLookup(accounts)),
      ),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWith(
        (ref) => Stream.value([accounts['cash']!, accounts['bank']!]),
      ),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.reimbursementReceivable,
      ).overrideWith((ref) => Stream.value([accounts['company']!])),
      transactionUpdateAppServiceProvider.overrideWithValue(
        update ?? _FakeTransactionUpdateAppService(),
      ),
      transactionEditAppServiceProvider.overrideWithValue(
        editService ?? _FakeTransactionEditAppService(),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(
        posting ?? _FakeTransactionPostingAppService(),
      ),
      installmentAppServiceProvider.overrideWithValue(
        installment ?? _FakeInstallmentAppService(),
      ),
      repaymentAppServiceProvider.overrideWithValue(
        repayment ?? _FakeRepaymentAppService(),
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
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
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
  return const PostedTransactionResult(transactionId: 'tx-1');
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

class _FakeTransactionEditAppService implements TransactionEditAppService {
  final canceledTransactionIds = <String>[];
  final expenseCommands = <EditExpenseCommand>[];
  final incomeCommands = <EditIncomeCommand>[];
  final reimbursementAdvanceCommands = <EditReimbursementAdvanceCommand>[];

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    canceledTransactionIds.add(command.transactionId);
  }

  @override
  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand command,
  ) async {
    reimbursementAdvanceCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editBorrowing(EditBorrowingCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editExpense(
    EditExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand command) async {
    incomeCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editRefund(EditRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editTransfer(EditTransferCommand command) {
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

class _FakeInstallmentAppService implements InstallmentAppService {
  _FakeInstallmentAppService({this.updateContractException});

  final Object? updateContractException;
  final updateContractCommands = <UpdateContractCommand>[];
  final deleteContractCommands = <DeleteContractCommand>[];

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    updateContractCommands.add(command);
    final exception = updateContractException;
    if (exception != null) throw exception;
  }

  @override
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> recalculateContractSchedules(
    RecalculateContractSchedulesCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreSchedule(RestoreInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<ContractStatusValidationResult> validateContractStatuses(
    ValidateContractStatusesCommand command,
  ) async {
    return const ContractStatusValidationResult(
      repairedScheduleCount: 0,
      contractStatusChanged: false,
    );
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    deleteContractCommands.add(command);
  }

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeRepaymentAppService implements RepaymentAppService {
  final editCommands = <EditCreditRepaymentTransactionCommand>[];
  final deleteCommands = <DeleteCreditRepaymentCommand>[];

  @override
  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  ) async {
    editCommands.add(command);
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
