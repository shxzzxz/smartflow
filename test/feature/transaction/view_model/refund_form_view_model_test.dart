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
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/refund_form_view_model.dart';
import 'package:smartflow/feature/transaction/view_model/reimbursement_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('loads refund edit values and submits refund edit command', () async {
    final editService = _FakeTransactionEditAppService();
    final container = _container(editService: editService);
    final provider = refundFormViewModelProvider('refund', editing: true);

    final state = await container.read(provider.future);

    expect(state.status, RefundFormStatus.loaded);
    expect(state.editing, isTrue);
    expect(state.parentTransactionId, 'parent');
    expect(state.amountText, '30');
    expect(state.noteText, 'original');
    expect(state.remaining, const Money(minorUnits: 9000));
    expect(state.refundToAccountId, 'bank');
    expect(state.occurredAt, DateTime(2026, 7, 2, 9));

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '35', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    final command = editService.refundCommands.single;
    expect(command.transactionId, 'refund');
    expect(command.amount, const Money(minorUnits: 3500));
    expect(command.settlementAllocations!.single.accountId, 'bank');
    expect(command.occurredAt, DateTime(2026, 7, 2, 9));
    expect(command.note, isA<PatchClear<String?>>());
  });

  test('prefills every original settlement account for a new refund', () async {
    final container = _container(combinedPayment: true);

    final state = await container.read(
      refundFormViewModelProvider('parent').future,
    );

    expect(state.status, RefundFormStatus.loaded);
    expect(state.refundToAccountId, 'cash');
    expect(
      state.settlementAllocations
          ?.map((allocation) => allocation.accountId)
          .toList(),
      ['cash', 'bank'],
    );
    expect(
      state.settlementAllocations
          ?.map((allocation) => allocation.amount.minorUnits)
          .toList(),
      [0, 0],
    );
  });

  test(
    'prefills every original settlement account for reimbursement forms',
    () async {
      final container = _container(combinedPayment: true);

      final receipt = await container.read(
        reimbursementReceiptFormViewModelProvider('parent').future,
      );
      final close = await container.read(
        reimbursementCloseFormViewModelProvider('parent').future,
      );
      final unified = await container.read(
        reimbursementFormViewModelProvider('parent').future,
      );

      expect(receipt.settlementAllocations, isNotNull);
      expect(close.settlementAllocations, isNotNull);
      expect(unified.settlementAllocations, isNotNull);
      for (final allocations in [
        receipt.settlementAllocations!,
        close.settlementAllocations!,
        unified.settlementAllocations!,
      ]) {
        expect(
          allocations?.map((allocation) => allocation.accountId).toList(),
          ['cash', 'bank'],
        );
        expect(
          allocations
              ?.map((allocation) => allocation.amount.minorUnits)
              .toList(),
          [0, 0],
        );
      }
    },
  );

  test('marks refund edit unavailable after reimbursement close', () async {
    final container = _container(closed: true);

    final state = await container.read(
      refundFormViewModelProvider('refund', editing: true).future,
    );

    expect(state.status, RefundFormStatus.notEditable);
  });

  test('refund edit remaining includes reimbursement receipts', () async {
    final container = _container(includeReceipt: true);

    final state = await container.read(
      refundFormViewModelProvider('refund', editing: true).future,
    );

    expect(state.status, RefundFormStatus.loaded);
    expect(state.remaining, const Money(minorUnits: 7000));
  });

  test('maps AppException to submit failure', () async {
    final editService = _FakeTransactionEditAppService(
      exception: BusinessException(
        LedgerErrorCode.transactionNotEditable,
        message: '退款当前不可编辑',
      ),
    );
    final container = _container(editService: editService);
    final provider = refundFormViewModelProvider('refund', editing: true);
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '35', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    final failure = outcome as SubmitFailure;
    expect(failure.error.code, LedgerErrorCode.transactionNotEditable.code);
    expect(failure.error.message, '退款当前不可编辑');
    expect(container.read(provider).requireValue.submitting, isFalse);
  });

  test('maps regular Exception to unknown submit failure', () async {
    final editService = _FakeTransactionEditAppService(
      exception: Exception('database failed'),
    );
    final container = _container(editService: editService);
    final provider = refundFormViewModelProvider('refund', editing: true);
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '35', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    expect((outcome as SubmitFailure).error.code, 'unknown');
    expect(container.read(provider).requireValue.submitting, isFalse);
  });
}

ProviderContainer _container({
  bool closed = false,
  bool includeReceipt = false,
  bool combinedPayment = false,
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
      accountLookupProvider.overrideWithValue(
        AsyncData(AccountLookup(accounts)),
      ),
      transactionDetailProvider(
        'refund',
      ).overrideWithValue(AsyncData(_refundDetail())),
      transactionDetailProvider('parent').overrideWithValue(
        AsyncData(
          _parentDetail(
            closed: closed,
            includeReceipt: includeReceipt,
            combinedPayment: combinedPayment,
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

TransactionReadModel _refundDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'refund',
      parentTransactionId: 'parent',
      businessPurpose: BusinessPurpose.refund,
      occurredAt: DateTime(2026, 7, 2, 9),
      primaryAmount: const Money(minorUnits: 3000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: 'original',
    ),
    createdAt: DateTime(2026, 7, 2, 9),
    lines: const [
      TransactionLine(
        id: 'refund-in',
        transactionId: 'refund',
        lineNo: 1,
        role: TransactionRole.settlementIn,
        accountId: 'bank',
        amount: Money(minorUnits: 3000),
      ),
      TransactionLine(
        id: 'refund-offset',
        transactionId: 'refund',
        lineNo: 2,
        role: TransactionRole.refundOffset,
        accountId: 'expense',
        amount: Money(minorUnits: 3000),
      ),
    ],
  );
}

TransactionReadModel _parentDetail({
  required bool closed,
  bool includeReceipt = false,
  bool combinedPayment = false,
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
      lines: combinedPayment ? _combinedAdvanceLines : _advanceLines,
    ),
    createdAt: DateTime(2026, 7, 1),
    lines: combinedPayment ? _combinedAdvanceLines : _advanceLines,
    children: [
      _child('refund', BusinessPurpose.refund, 3000),
      _child('other-refund', BusinessPurpose.refund, 1000),
      if (includeReceipt)
        _child('receipt', BusinessPurpose.reimbursementReceipt, 2000),
      if (closed) _child('close', BusinessPurpose.reimbursementClose, 6000),
    ],
  );
}

TransactionReadModel _child(String id, BusinessPurpose purpose, int amount) {
  return TransactionReadModel(
    id: id,
    parentTransactionId: 'parent',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 7, 2),
    primaryAmount: Money(minorUnits: amount),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    impactsByAccountId: const {},
  );
}

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
}

class _FakeTransactionEditAppService implements TransactionEditAppService {
  _FakeTransactionEditAppService({this.exception});

  final Object? exception;
  final refundCommands = <EditRefundCommand>[];

  @override
  Future<PostedTransactionResult> editRefund(EditRefundCommand command) async {
    if (exception != null) throw exception!;
    refundCommands.add(command);
    return const PostedTransactionResult(transactionId: 'refund');
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
  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand command,
  ) => throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand command,
  ) => throw UnimplementedError();

  @override
  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand command,
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
];

const _combinedAdvanceLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'parent',
    lineNo: 1,
    role: TransactionRole.reimbursementExpenseCategory,
    accountId: 'expense',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-out-cash',
    transactionId: 'parent',
    lineNo: 2,
    role: TransactionRole.settlementOut,
    accountId: 'cash',
    amount: Money(minorUnits: 6000),
  ),
  TransactionLine(
    id: 'advance-out-bank',
    transactionId: 'parent',
    lineNo: 3,
    role: TransactionRole.settlementOut,
    accountId: 'bank',
    amount: Money(minorUnits: 4000),
  ),
  TransactionLine(
    id: 'advance-receivable',
    transactionId: 'parent',
    lineNo: 4,
    role: TransactionRole.receivable,
    accountId: 'receivable',
    amount: Money(minorUnits: 10000),
  ),
];
