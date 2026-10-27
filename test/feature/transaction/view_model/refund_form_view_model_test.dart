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
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/refund_form_view_model.dart';
import 'package:smartflow/feature/transaction/view_model/advance_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('loads refund edit values and submits refund edit command', () async {
    final orchestration = _FakeAdvanceOrchestrationService();
    final container = _container(orchestration: orchestration);
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
    final command = orchestration.refundCommands.single;
    expect(command.transactionId, 'refund');
    expect(command.amount, const Money(minorUnits: 3500));
    expect(command.settlementAllocations.single.accountId, 'bank');
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
    'prefills every original settlement account for advance forms',
    () async {
      final container = _container(combinedPayment: true);

      final receipt = await container.read(
        advanceCollectionFormViewModelProvider('parent').future,
      );
      final close = await container.read(
        advanceSettlementFormViewModelProvider('parent').future,
      );
      final unified = await container.read(
        advanceFormViewModelProvider('parent').future,
      );

      expect(receipt.settlementAllocations, isNotNull);
      expect(close.settlementAllocations, isNotNull);
      expect(unified.settlementAllocations, isNotNull);
      for (final allocations in [
        receipt.settlementAllocations!,
        close.settlementAllocations!,
        unified.settlementAllocations!,
      ]) {
        expect(allocations.map((allocation) => allocation.accountId).toList(), [
          'cash',
          'bank',
        ]);
        expect(
          allocations
              .map((allocation) => allocation.amount.minorUnits)
              .toList(),
          [0, 0],
        );
      }
    },
  );

  test('submits a visible single-category default for advance close', () async {
    final posting = _FakeAdvanceOrchestrationService();
    final container = _container(orchestration: posting);
    final provider = advanceSettlementFormViewModelProvider('parent');
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '50', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    final gaps = posting.closeCommands.single.gapExpenseAllocations;
    expect(gaps, hasLength(1));
    expect(gaps.single.accountId, 'expense');
    expect(gaps.single.amount, const Money(minorUnits: 1000));
  });

  test('does not recreate a cleared single-category default', () async {
    final posting = _FakeAdvanceOrchestrationService();
    final container = _container(orchestration: posting);
    final provider = advanceSettlementFormViewModelProvider('parent');
    await container.read(provider.future);
    container.read(provider.notifier).setGapExpenseAllocations(const []);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '50', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    expect(posting.closeCommands, isEmpty);
  });

  test('marks refund edit unavailable after advance close', () async {
    final container = _container(closed: true);

    final state = await container.read(
      refundFormViewModelProvider('refund', editing: true).future,
    );

    expect(state.status, RefundFormStatus.notEditable);
  });

  test('refund edit remaining uses the full parent transaction', () async {
    final container = _container(includeReceipt: true);

    final state = await container.read(
      refundFormViewModelProvider('refund', editing: true).future,
    );

    expect(state.status, RefundFormStatus.loaded);
    expect(state.remaining, const Money(minorUnits: 9000));
  });

  test(
    'new refund remaining includes self-borne and advance portions',
    () async {
      final container = _container(includeReceipt: true);

      final state = await container.read(
        refundFormViewModelProvider('parent').future,
      );

      expect(state.status, RefundFormStatus.loaded);
      expect(state.remaining, const Money(minorUnits: 6000));
    },
  );

  test('maps AppException to submit failure', () async {
    final orchestration = _FakeAdvanceOrchestrationService(
      exception: BusinessException(
        LedgerErrorCode.transactionNotEditable,
        message: '退款当前不可编辑',
      ),
    );
    final container = _container(orchestration: orchestration);
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
    final orchestration = _FakeAdvanceOrchestrationService(
      exception: Exception('database failed'),
    );
    final container = _container(orchestration: orchestration);
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
  _FakeAdvanceOrchestrationService? orchestration,
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
      advanceOrchestrationAppServiceProvider.overrideWithValue(
        orchestration ?? _FakeAdvanceOrchestrationService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeAdvanceOrchestrationService
    implements AdvanceOrchestrationAppService {
  _FakeAdvanceOrchestrationService({this.exception});

  final Object? exception;
  final closeCommands = <CreateAdvanceSettlementWorkflowCommand>[];
  final refundCommands = <EditAdvanceRefundWorkflowCommand>[];

  @override
  Future<String> createSettlement(
    CreateAdvanceSettlementWorkflowCommand command,
  ) async {
    if (exception != null) throw exception!;
    closeCommands.add(command);
    return 'close';
  }

  @override
  Future<String> editRefund(EditAdvanceRefundWorkflowCommand command) async {
    if (exception != null) throw exception!;
    refundCommands.add(command);
    return 'refund';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
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
      businessPurpose: BusinessPurpose.advance,
      occurredAt: DateTime(2026, 7, 1),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: combinedPayment ? _combinedAdvanceLines : _advanceLines,
    ),
    createdAt: DateTime(2026, 7, 1),
    lines: combinedPayment ? _combinedAdvanceLines : _advanceLines,
    refundSummary: RefundSummary(
      refundedTotal: const Money(minorUnits: 4000),
      originalCategoryAllocations: [
        const AccountAmountAllocation(
          accountId: 'expense',
          amount: Money(minorUnits: 10000),
        ),
      ],
      refundedCategoryAllocations: const [],
    ),
    advanceSummary: AdvanceSummary(
      advanceAmount: const Money(minorUnits: 10000),
      refundedAmount: const Money(minorUnits: 4000),
      receivedAmount:
          Money(minorUnits: includeReceipt ? 2000 : 0) +
          (closed ? const Money(minorUnits: 6000) : Money.zero()),
      outstanding: closed
          ? Money.zero()
          : const Money(minorUnits: 10000) -
                const Money(minorUnits: 4000) -
                (includeReceipt ? const Money(minorUnits: 2000) : Money.zero()),
      isClosed: closed,
    ),
    children: [
      _child('refund', BusinessPurpose.refund, 3000),
      _child('other-refund', BusinessPurpose.refund, 1000),
      if (includeReceipt)
        _child('receipt', BusinessPurpose.advanceCollection, 2000),
      if (closed) _child('close', BusinessPurpose.advanceSettlement, 6000),
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
    lines: [_line(id, 1, TransactionRole.settlementIn, amount, 'bank')],
  );
}

TransactionLine _line(
  String transactionId,
  int lineNo,
  TransactionRole role,
  int amount,
  String accountId,
) => TransactionLine(
  id: '$transactionId-$lineNo',
  transactionId: transactionId,
  lineNo: lineNo,
  role: role,
  accountId: accountId,
  amount: Money(minorUnits: amount),
);

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
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

const _combinedAdvanceLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'parent',
    lineNo: 1,
    role: TransactionRole.advanceExpenseCategory,
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
