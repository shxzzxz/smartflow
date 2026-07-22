import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/reimbursement_edit_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test(
    'loads receipt mode and submits receipt edit without mode switching',
    () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(editService: editService);

      final state = await container.read(
        reimbursementEditFormViewModelProvider('receipt').future,
      );

      expect(state.status, ReimbursementEditFormStatus.loaded);
      expect(state.kind, ReimbursementEditKind.receipt);
      expect(state.parentTransactionId, 'parent');
      expect(state.amountText, '40');
      expect(
        state.outstandingBeforeTransaction,
        const Money(minorUnits: 10000),
      );
      expect(state.receiveAccountId, 'bank');
      expect(state.noteText, 'original receipt');

      final outcome = await container
          .read(reimbursementEditFormViewModelProvider('receipt').notifier)
          .submit(amountText: '45', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      expect(editService.closeCommands, isEmpty);
      final command = editService.receiptCommands.single;
      expect(command.transactionId, 'receipt');
      expect(command.amount, const Money(minorUnits: 4500));
      expect(command.receivableAccountId, 'receivable');
      expect(command.receiveAccountId, 'bank');
      expect(command.occurredAt, DateTime(2026, 7, 2, 9));
      expect(command.note, isA<PatchClear<String?>>());
    },
  );

  test('blocks receipt editing after reimbursement close', () async {
    final container = _container(closed: true);

    final state = await container.read(
      reimbursementEditFormViewModelProvider('receipt').future,
    );

    expect(state.status, ReimbursementEditFormStatus.notEditable);
    expect(state.kind, ReimbursementEditKind.receipt);
  });

  test(
    'keeps close mode fixed and allows zero amount without receive account',
    () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        closed: true,
        editService: editService,
        includeClose: true,
      );

      final state = await container.read(
        reimbursementEditFormViewModelProvider('close').future,
      );

      expect(state.status, ReimbursementEditFormStatus.loaded);
      expect(state.kind, ReimbursementEditKind.close);
      expect(state.amountText, '0');
      expect(state.outstandingBeforeTransaction, const Money(minorUnits: 6000));
      expect(state.receiveAccountId, isNull);

      final outcome = await container
          .read(reimbursementEditFormViewModelProvider('close').notifier)
          .submit(amountText: '0', noteText: 'updated close');

      expect(outcome, isA<SubmitSuccess>());
      expect(editService.receiptCommands, isEmpty);
      final command = editService.closeCommands.single;
      expect(command.transactionId, 'close');
      expect(command.actualReceivedAmount, Money.zero());
      expect(command.receivableAccountId, 'receivable');
      expect(command.receiveAccountId, 'receivable');
      expect(command.note, isA<PatchSet<String?>>());
    },
  );

  test(
    'zero amount close replaces the original receive account with receivable',
    () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        closed: true,
        editService: editService,
        includeClose: true,
        closeHasReceiveAccount: true,
      );

      final state = await container.read(
        reimbursementEditFormViewModelProvider('close').future,
      );

      expect(state.receiveAccountId, 'bank');

      final outcome = await container
          .read(reimbursementEditFormViewModelProvider('close').notifier)
          .submit(amountText: '0', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.closeCommands.single;
      expect(command.actualReceivedAmount, Money.zero());
      expect(command.receiveAccountId, 'receivable');
    },
  );

  test('maps AppException to submit failure', () async {
    final editService = _FakeTransactionEditAppService(
      exception: BusinessException(
        LedgerErrorCode.transactionNotEditable,
        message: '报销当前不可编辑',
      ),
    );
    final container = _container(editService: editService);
    final provider = reimbursementEditFormViewModelProvider('receipt');
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '45', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    final failure = outcome as SubmitFailure;
    expect(failure.error.code, LedgerErrorCode.transactionNotEditable.code);
    expect(failure.error.message, '报销当前不可编辑');
    expect(container.read(provider).requireValue.submitting, isFalse);
  });

  test('maps regular Exception to unknown submit failure', () async {
    final editService = _FakeTransactionEditAppService(
      exception: Exception('database failed'),
    );
    final container = _container(editService: editService);
    final provider = reimbursementEditFormViewModelProvider('receipt');
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '45', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    expect((outcome as SubmitFailure).error.code, 'unknown');
    expect(container.read(provider).requireValue.submitting, isFalse);
  });
}

ProviderContainer _container({
  bool closed = false,
  bool includeClose = false,
  bool closeHasReceiveAccount = false,
  _FakeTransactionEditAppService? editService,
}) {
  final cash = _account('cash');
  final bank = _account('bank');
  final receivable = _account('receivable');
  final expense = _account('expense', type: AccountType.expense);
  final accounts = {
    'cash': cash,
    'bank': bank,
    'receivable': receivable,
    'expense': expense,
  };
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash, bank])),
      accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
      transactionDetailProvider(
        'parent',
      ).overrideWithValue(AsyncData(_parentDetail(closed: closed))),
      transactionDetailProvider(
        'receipt',
      ).overrideWithValue(AsyncData(_receiptDetail())),
      if (includeClose)
        transactionDetailProvider('close').overrideWithValue(
          AsyncData(
            _closeDetail(
              actualReceivedMinorUnits: closeHasReceiveAccount ? 1000 : 0,
            ),
          ),
        ),
      transactionEditAppServiceProvider.overrideWithValue(
        editService ?? _FakeTransactionEditAppService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionDetail _parentDetail({required bool closed}) {
  final entries = [
    _entry('parent', 'receivable', EntryDirection.debit, 10000),
    _entry('parent', 'cash', EntryDirection.credit, 10000),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'parent',
      businessPurpose: BusinessPurpose.reimbursementAdvance,
      occurredAt: DateTime(2026, 7, 1),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      reimbursementExpenseAccountId: 'expense',
      entries: entries,
    ),
    createdAt: DateTime(2026, 7, 1),
    details: const [],
    entries: entries,
    reimbursementSummary: ReimbursementSummary(
      advanceAmount: const Money(minorUnits: 10000),
      receivedAmount: Money(minorUnits: closed ? 10000 : 4000),
      outstanding: Money(minorUnits: closed ? 0 : 6000),
      isClosed: closed,
    ),
  );
}

TransactionDetail _receiptDetail() {
  final entries = [
    _entry('receipt', 'bank', EntryDirection.debit, 4000),
    _entry('receipt', 'receivable', EntryDirection.credit, 4000),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'receipt',
      parentTransactionId: 'parent',
      businessPurpose: BusinessPurpose.reimbursementReceipt,
      occurredAt: DateTime(2026, 7, 2, 9),
      primaryAmount: const Money(minorUnits: 4000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: 'original receipt',
      entries: entries,
    ),
    createdAt: DateTime(2026, 7, 2, 9),
    details: const [],
    entries: entries,
  );
}

TransactionDetail _closeDetail({required int actualReceivedMinorUnits}) {
  final gapExpenseMinorUnits = 6000 - actualReceivedMinorUnits;
  final entries = [
    if (actualReceivedMinorUnits > 0)
      _entry('close', 'bank', EntryDirection.debit, actualReceivedMinorUnits),
    _entry('close', 'receivable', EntryDirection.credit, 6000),
    if (gapExpenseMinorUnits > 0)
      _entry('close', 'expense', EntryDirection.debit, gapExpenseMinorUnits),
  ];
  final details = [
    _detail('close', 1, TransactionDetailType.reimbursementCloseMain, 6000),
    if (gapExpenseMinorUnits > 0)
      _detail(
        'close',
        2,
        TransactionDetailType.reimbursementGapExpense,
        gapExpenseMinorUnits,
      ),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'close',
      parentTransactionId: 'parent',
      businessPurpose: BusinessPurpose.reimbursementClose,
      occurredAt: DateTime(2026, 7, 3, 10),
      primaryAmount: const Money(minorUnits: 6000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: 'original close',
      details: details,
      entries: entries,
    ),
    createdAt: DateTime(2026, 7, 3, 10),
    details: details,
    entries: entries,
  );
}

Entry _entry(
  String transactionId,
  String accountId,
  EntryDirection direction,
  int amount,
) {
  return Entry(
    id: '$transactionId-$accountId',
    transactionId: transactionId,
    accountId: accountId,
    direction: direction,
    amount: Money(minorUnits: amount),
  );
}

TransactionDetailRecord _detail(
  String transactionId,
  int lineNo,
  TransactionDetailType type,
  int amount,
) {
  return TransactionDetailRecord(
    id: '$transactionId-$lineNo',
    transactionId: transactionId,
    lineNo: lineNo,
    type: type,
    amount: Money(minorUnits: amount),
  );
}

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
}

class _FakeTransactionEditAppService implements TransactionEditAppService {
  _FakeTransactionEditAppService({this.exception});

  final Object? exception;
  final receiptCommands = <EditReimbursementReceiptCommand>[];
  final closeCommands = <EditReimbursementCloseCommand>[];

  @override
  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand command,
  ) async {
    if (exception != null) throw exception!;
    receiptCommands.add(command);
    return const PostedTransactionResult(transactionId: 'receipt');
  }

  @override
  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand command,
  ) async {
    if (exception != null) throw exception!;
    closeCommands.add(command);
    return const PostedTransactionResult(transactionId: 'close');
  }

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editBorrowing(EditBorrowingCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editExpense(EditExpenseCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editRefund(EditRefundCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand command,
  ) => throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command) =>
      throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editTransfer(EditTransferCommand command) =>
      throw UnimplementedError();
}
