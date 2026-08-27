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
      expect(command.settlementAllocations!.single.accountId, 'bank');
      expect(command.occurredAt, DateTime(2026, 7, 2, 9));
      expect(command.note, isA<PatchClear<String?>>());
    },
  );

  test('receipt edit remaining includes refunds', () async {
    final container = _container(includeRefund: true);

    final state = await container.read(
      reimbursementEditFormViewModelProvider('receipt').future,
    );

    expect(state.status, ReimbursementEditFormStatus.loaded);
    expect(state.outstandingBeforeTransaction, const Money(minorUnits: 8000));
  });

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
      expect(command.settlementAllocations!.single.accountId, 'receivable');
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
      expect(command.settlementAllocations!.single.accountId, 'receivable');
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
  bool includeRefund = false,
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
      transactionDetailProvider('parent').overrideWithValue(
        AsyncData(_parentDetail(closed: closed, includeRefund: includeRefund)),
      ),
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

TransactionReadModel _parentDetail({
  required bool closed,
  bool includeRefund = false,
}) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'parent',
      businessPurpose: BusinessPurpose.reimbursementAdvance,
      occurredAt: DateTime(2026, 7, 1),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: _advanceLines,
    ),
    createdAt: DateTime(2026, 7, 1),
    lines: _advanceLines,
    children: [
      if (!closed)
        TransactionReadModel(
          id: 'receipt-child',
          parentTransactionId: 'parent',
          businessPurpose: BusinessPurpose.reimbursementReceipt,
          occurredAt: DateTime(2026, 7, 2),
          primaryAmount: const Money(minorUnits: 4000),
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            _line(
              'receipt-child',
              1,
              TransactionRole.settlementIn,
              4000,
              'bank',
            ),
          ],
        ),
      if (includeRefund)
        TransactionReadModel(
          id: 'refund-child',
          parentTransactionId: 'parent',
          businessPurpose: BusinessPurpose.refund,
          occurredAt: DateTime(2026, 7, 2),
          primaryAmount: const Money(minorUnits: 2000),
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            _line(
              'refund-child',
              1,
              TransactionRole.settlementIn,
              2000,
              'bank',
            ),
          ],
        ),
      if (closed)
        TransactionReadModel(
          id: 'close-child',
          parentTransactionId: 'parent',
          businessPurpose: BusinessPurpose.reimbursementClose,
          occurredAt: DateTime(2026, 7, 3),
          primaryAmount: Money.zero(),
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            _line('close-child', 1, TransactionRole.settlementIn, 0, 'bank'),
          ],
        ),
    ],
  );
}

TransactionReadModel _receiptDetail() {
  return TransactionReadModel.fromTransaction(
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
    ),
    createdAt: DateTime(2026, 7, 2, 9),
    lines: const [
      TransactionLine(
        id: 'receipt-in',
        transactionId: 'receipt',
        lineNo: 1,
        role: TransactionRole.settlementIn,
        accountId: 'bank',
        amount: Money(minorUnits: 4000),
      ),
      TransactionLine(
        id: 'receipt-receivable',
        transactionId: 'receipt',
        lineNo: 2,
        role: TransactionRole.receivable,
        accountId: 'receivable',
        amount: Money(minorUnits: 4000),
      ),
    ],
  );
}

TransactionReadModel _closeDetail({required int actualReceivedMinorUnits}) {
  final gapExpenseMinorUnits = 6000 - actualReceivedMinorUnits;
  final lines = [
    _line(
      'close',
      1,
      TransactionRole.settlementIn,
      actualReceivedMinorUnits,
      'bank',
    ),
    _line('close', 2, TransactionRole.receivable, 6000, 'receivable'),
    if (gapExpenseMinorUnits > 0)
      _line(
        'close',
        3,
        TransactionRole.reimbursementGapExpense,
        gapExpenseMinorUnits,
        'expense',
      ),
  ];
  return TransactionReadModel.fromTransaction(
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
      lines: lines,
    ),
    createdAt: DateTime(2026, 7, 3, 10),
    lines: lines,
  );
}

TransactionLine _line(
  String transactionId,
  int lineNo,
  TransactionRole type,
  int amount, [
  String? accountId,
]) {
  return TransactionLine(
    id: '$transactionId-$lineNo',
    transactionId: transactionId,
    lineNo: lineNo,
    role: type,
    accountId: accountId,
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

  @override
  Future<PostedTransactionResult> replaceTransactionCategory(
    ReplaceTransactionCategoryCommand command,
  ) => throw UnimplementedError();
}

const _advanceLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'parent',
    lineNo: 1,
    role: TransactionRole.reimbursementExpenseCategory,
    accountId: 'expense',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-out',
    transactionId: 'parent',
    lineNo: 2,
    role: TransactionRole.settlementOut,
    accountId: 'cash',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-receivable',
    transactionId: 'parent',
    lineNo: 3,
    role: TransactionRole.receivable,
    accountId: 'receivable',
    amount: Money(minorUnits: 10000),
  ),
];
