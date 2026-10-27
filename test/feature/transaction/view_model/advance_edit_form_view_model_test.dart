import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/advance_edit_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import '../../../helper/advance_ownership_fixtures.dart';
import '../../../helper/fake_advance_case_repository.dart';

void main() {
  test(
    'loads receipt mode and submits receipt edit without mode switching',
    () async {
      final editService = _FakeAdvanceEditOrchestrationService();
      final container = _container(editService: editService);

      final state = await container.read(
        advanceEditFormViewModelProvider('receipt').future,
      );

      expect(state.status, AdvanceEditFormStatus.loaded);
      expect(state.kind, AdvanceEditKind.receipt);
      expect(state.parentTransactionId, 'parent');
      expect(state.amountText, '40');
      expect(
        state.outstandingBeforeTransaction,
        const Money(minorUnits: 10000),
      );
      expect(state.receiveAccountId, 'bank');
      expect(state.noteText, 'original receipt');

      final outcome = await container
          .read(advanceEditFormViewModelProvider('receipt').notifier)
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
      advanceEditFormViewModelProvider('receipt').future,
    );

    expect(state.status, AdvanceEditFormStatus.loaded);
    expect(state.outstandingBeforeTransaction, const Money(minorUnits: 8000));
  });

  test('blocks receipt editing after advance close', () async {
    final container = _container(closed: true);

    final state = await container.read(
      advanceEditFormViewModelProvider('receipt').future,
    );

    expect(state.status, AdvanceEditFormStatus.notEditable);
    expect(state.kind, AdvanceEditKind.receipt);
  });

  test('loads and edits an account-managed receipt transaction', () async {
    final editService = _FakeAdvanceEditOrchestrationService();
    final container = _container(
      editService: editService,
      includeAccountManagedReceipt: true,
    );

    final state = await container.read(
      advanceEditFormViewModelProvider('account-receipt').future,
    );

    expect(state.status, AdvanceEditFormStatus.loaded);
    expect(state.kind, AdvanceEditKind.receipt);
    expect(state.parentTransactionId, isNull);
    expect(state.outstandingBeforeTransaction, isNull);
    expect(state.amountText, '40');

    final outcome = await container
        .read(advanceEditFormViewModelProvider('account-receipt').notifier)
        .submit(amountText: '45', noteText: 'updated account receipt');

    expect(outcome, isA<SubmitSuccess>());
    final command = editService.receiptCommands.single;
    expect(command.transactionId, 'account-receipt');
    expect(command.amount, const Money(minorUnits: 4500));
    expect(command.receivableAccountId, 'receivable');
  });

  test('loads and edits an account-managed settlement transaction', () async {
    final editService = _FakeAdvanceEditOrchestrationService();
    final container = _container(
      editService: editService,
      includeAccountManagedClose: true,
    );

    final state = await container.read(
      advanceEditFormViewModelProvider('account-close').future,
    );

    expect(state.status, AdvanceEditFormStatus.loaded);
    expect(state.kind, AdvanceEditKind.close);
    expect(state.parentTransactionId, isNull);
    expect(state.outstandingBeforeTransaction, isNull);
    expect(state.amountText, '60');

    final outcome = await container
        .read(advanceEditFormViewModelProvider('account-close').notifier)
        .submit(amountText: '70', noteText: 'updated account close');

    expect(outcome, isA<SubmitSuccess>());
    final command = editService.closeCommands.single;
    expect(command.transactionId, 'account-close');
    expect(command.actualReceivedAmount, const Money(minorUnits: 7000));
    expect(command.receivableAccountId, 'receivable');
    expect(command.gapExpenseAllocations, isEmpty);
  });

  test(
    'keeps close mode fixed and allows zero amount without receive account',
    () async {
      final editService = _FakeAdvanceEditOrchestrationService();
      final container = _container(
        closed: true,
        editService: editService,
        includeClose: true,
      );

      final state = await container.read(
        advanceEditFormViewModelProvider('close').future,
      );

      expect(state.status, AdvanceEditFormStatus.loaded);
      expect(state.kind, AdvanceEditKind.close);
      expect(state.amountText, '0');
      expect(state.outstandingBeforeTransaction, const Money(minorUnits: 6000));
      expect(state.receiveAccountId, isNull);
      expect(state.settlementAllocations, isEmpty);

      final outcome = await container
          .read(advanceEditFormViewModelProvider('close').notifier)
          .submit(amountText: '0', noteText: 'updated close');

      expect(outcome, isA<SubmitSuccess>());
      expect(editService.receiptCommands, isEmpty);
      final command = editService.closeCommands.single;
      expect(command.transactionId, 'close');
      expect(command.actualReceivedAmount, Money.zero());
      expect(command.receivableAccountId, 'receivable');
      expect(command.settlementAllocations!.single.accountId, 'receivable');
      expect(command.note, isA<PatchSet<String?>>());
      expect((command.note as PatchSet<String?>).value, 'updated close');
    },
  );

  test(
    'zero amount close replaces the original receive account with receivable',
    () async {
      final editService = _FakeAdvanceEditOrchestrationService();
      final container = _container(
        closed: true,
        editService: editService,
        includeClose: true,
        closeHasReceiveAccount: true,
      );

      final state = await container.read(
        advanceEditFormViewModelProvider('close').future,
      );

      expect(state.receiveAccountId, 'bank');

      final outcome = await container
          .read(advanceEditFormViewModelProvider('close').notifier)
          .submit(amountText: '0', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.closeCommands.single;
      expect(command.actualReceivedAmount, Money.zero());
      expect(command.settlementAllocations!.single.accountId, 'receivable');
    },
  );

  test(
    'edit loads bad-debt allocation from its expense classification',
    () async {
      final editService = _FakeAdvanceEditOrchestrationService();
      final container = _container(
        closed: true,
        editService: editService,
        includeClose: true,
        closeBadDebt: true,
      );

      final state = await container.read(
        advanceEditFormViewModelProvider('close').future,
      );

      expect(state.shortfallKind, AdvanceShortfallKind.badDebt);
      expect(state.gapExpenseAllocations, isEmpty);

      final outcome = await container
          .read(advanceEditFormViewModelProvider('close').notifier)
          .submit(amountText: '0', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.closeCommands.single;
      expect(command.shortfallKind, AdvanceShortfallKind.badDebt);
      expect(command.gapExpenseAllocations, isEmpty);
    },
  );

  test('maps AppException to submit failure', () async {
    final editService = _FakeAdvanceEditOrchestrationService(
      exception: BusinessException(
        LedgerErrorCode.transactionNotEditable,
        message: '报销当前不可编辑',
      ),
    );
    final container = _container(editService: editService);
    final provider = advanceEditFormViewModelProvider('receipt');
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
    final editService = _FakeAdvanceEditOrchestrationService(
      exception: Exception('database failed'),
    );
    final container = _container(editService: editService);
    final provider = advanceEditFormViewModelProvider('receipt');
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
  bool includeAccountManagedReceipt = false,
  bool includeAccountManagedClose = false,
  bool closeHasReceiveAccount = false,
  bool closeBadDebt = false,
  _FakeAdvanceEditOrchestrationService? editService,
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
              badDebt: closeBadDebt,
            ),
          ),
        ),
      if (includeAccountManagedReceipt)
        transactionDetailProvider(
          'account-receipt',
        ).overrideWithValue(AsyncData(_accountManagedReceiptDetail())),
      if (includeAccountManagedClose)
        transactionDetailProvider(
          'account-close',
        ).overrideWithValue(AsyncData(_accountManagedCloseDetail())),
      advanceOrchestrationAppServiceProvider.overrideWithValue(
        editService ?? _FakeAdvanceEditOrchestrationService(),
      ),
      advanceCaseRepositoryProvider.overrideWithValue(
        FakeAdvanceCaseRepository([
          if (includeAccountManagedReceipt || includeAccountManagedClose)
            const AdvanceCase(
              id: 'receivable',
              scenario: AdvanceScenario.reimbursement,
              trackingMode: AdvanceTrackingMode.account,
              receivableAccountId: 'receivable',
            ),
        ]),
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
      businessPurpose: BusinessPurpose.advance,
      occurredAt: DateTime(2026, 7, 1),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: _advanceLines,
    ),
    createdAt: DateTime(2026, 7, 1),
    lines: _advanceLines,
    refundSummary: RefundSummary(
      refundedTotal: Money(minorUnits: includeRefund ? 2000 : 0),
      originalCategoryAllocations: const [
        AccountAmountAllocation(
          accountId: 'expense',
          amount: Money(minorUnits: 10000),
        ),
      ],
      refundedCategoryAllocations: const [],
    ),
    advanceSummary: AdvanceSummary(
      advanceAmount: const Money(minorUnits: 10000),
      refundedAmount: Money(minorUnits: includeRefund ? 2000 : 0),
      receivedAmount: closed ? Money.zero() : const Money(minorUnits: 4000),
      outstanding: closed
          ? Money.zero()
          : Money(minorUnits: 10000 - (includeRefund ? 2000 : 0) - 4000),
      isClosed: closed,
    ),
    children: [
      if (!closed)
        TransactionReadModel(
          id: 'receipt-child',
          parentTransactionId: 'parent',
          businessPurpose: BusinessPurpose.advanceCollection,
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
          businessPurpose: BusinessPurpose.advanceSettlement,
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
      businessPurpose: BusinessPurpose.advanceCollection,
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

TransactionReadModel _accountManagedReceiptDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'account-receipt',
      businessPurpose: BusinessPurpose.advanceCollection,
      occurredAt: DateTime(2026, 7, 2, 9),
      primaryAmount: const Money(minorUnits: 4000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: advanceOwnership(
        management: AdvanceTrackingMode.account,
        ownerId: 'receivable',
        scenario: AdvanceScenario.reimbursement,
      ),
    ),
    createdAt: DateTime(2026, 7, 2, 9),
    lines: const [
      TransactionLine(
        id: 'account-receipt-in',
        transactionId: 'account-receipt',
        lineNo: 1,
        role: TransactionRole.settlementIn,
        accountId: 'bank',
        amount: Money(minorUnits: 4000),
      ),
      TransactionLine(
        id: 'account-receipt-receivable',
        transactionId: 'account-receipt',
        lineNo: 2,
        role: TransactionRole.receivable,
        accountId: 'receivable',
        amount: Money(minorUnits: 4000),
      ),
    ],
  );
}

TransactionReadModel _accountManagedCloseDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'account-close',
      businessPurpose: BusinessPurpose.advanceSettlement,
      occurredAt: DateTime(2026, 7, 3, 10),
      primaryAmount: const Money(minorUnits: 6000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: advanceOwnership(
        management: AdvanceTrackingMode.account,
        ownerId: 'receivable',
        scenario: AdvanceScenario.reimbursement,
      ),
    ),
    createdAt: DateTime(2026, 7, 3, 10),
    lines: const [
      TransactionLine(
        id: 'account-close-in',
        transactionId: 'account-close',
        lineNo: 1,
        role: TransactionRole.settlementIn,
        accountId: 'bank',
        amount: Money(minorUnits: 6000),
      ),
      TransactionLine(
        id: 'account-close-receivable',
        transactionId: 'account-close',
        lineNo: 2,
        role: TransactionRole.receivable,
        accountId: 'receivable',
        amount: Money(minorUnits: 6000),
      ),
    ],
  );
}

TransactionReadModel _closeDetail({
  required int actualReceivedMinorUnits,
  bool badDebt = false,
}) {
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
        badDebt
            ? TransactionRole.advanceBadDebtExpense
            : TransactionRole.advanceSelfBorne,
        gapExpenseMinorUnits,
        badDebt ? null : 'expense',
      ),
  ];
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'close',
      parentTransactionId: 'parent',
      businessPurpose: BusinessPurpose.advanceSettlement,
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

class _FakeAdvanceEditOrchestrationService
    implements AdvanceOrchestrationAppService {
  _FakeAdvanceEditOrchestrationService({this.exception});

  final Object? exception;
  final receiptCommands = <EditAdvanceCollectionWorkflowCommand>[];
  final closeCommands = <EditAdvanceSettlementWorkflowCommand>[];

  @override
  Future<String> editCollection(
    EditAdvanceCollectionWorkflowCommand command,
  ) async {
    if (exception != null) throw exception!;
    receiptCommands.add(command);
    return 'receipt';
  }

  @override
  Future<String> editSettlement(
    EditAdvanceSettlementWorkflowCommand command,
  ) async {
    if (exception != null) throw exception!;
    closeCommands.add(command);
    return 'close';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _advanceLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'parent',
    lineNo: 1,
    role: TransactionRole.advanceExpenseCategory,
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
