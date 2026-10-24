import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state_builder.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  for (final scenario in [
    (
      BusinessPurpose.lending,
      TransactionRole.receivable,
      'receivable',
      ['付款账户', '应收账户'],
      ['cash', 'receivable'],
    ),
    (
      BusinessPurpose.debtRepayment,
      TransactionRole.liability,
      'loan',
      ['还款账户', '负债账户'],
      ['cash', 'loan'],
    ),
    (
      BusinessPurpose.borrowing,
      TransactionRole.liability,
      'loan',
      ['负债账户', '收支账户'],
      ['loan', 'cash'],
    ),
    (
      BusinessPurpose.receivableCollection,
      TransactionRole.receivable,
      'receivable',
      ['应收账户', '收支账户'],
      ['receivable', 'cash'],
    ),
  ]) {
    test('shows both account roles for ${scenario.$1.name}', () {
      final state = _build(
        purpose: scenario.$1,
        parentTransactionId: null,
        counterpart: TransactionLine(
          id: 'counterpart',
          transactionId: 'child',
          lineNo: 2,
          role: scenario.$2,
          accountId: scenario.$3,
          amount: const Money(minorUnits: 1000),
        ),
      );
      expect(state.accountRows.map((row) => row.label), scenario.$4);
      expect(state.accountRows.map((row) => row.accountId), scenario.$5);
      final counterpart = state.accountRows.singleWhere(
        (row) => row.accountId == scenario.$3,
      );
      expect(
        counterpart.endpoint.label,
        scenario.$3 == 'receivable' ? '应收款' : '借款',
      );
      expect(counterpart.endpoint.iconKey, scenario.$3);
      expect(counterpart.editPurpose, isNull);
    });
  }

  test(
    'routes refund child to refund edit and locks it after advance close',
    () {
      final state = _build(
        purpose: BusinessPurpose.refund,
        advanceSummary: const AdvanceSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 10000),
          outstanding: Money(minorUnits: 0),
          isClosed: true,
        ),
      );

      expect(state.behavior.editRoute, '/transaction/child/refund/edit');
      final edit = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(edit.enabled, isFalse);
      expect(edit.deniedReason, '垫付已结清，请先删除垫付结清');
      expect(state.behavior.canEditNote, isA<DetailEditAllowed>());
    },
  );

  test('routes open advance receipt child to shared advance edit', () {
    final state = _build(
      purpose: BusinessPurpose.advanceCollection,
      advanceSummary: const AdvanceSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 4000),
        outstanding: Money(minorUnits: 6000),
        isClosed: false,
      ),
    );

    expect(state.behavior.editRoute, '/transaction/child/advance/edit');
    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(edit.enabled, isTrue);
  });

  test('routes advance action to the standalone advance form', () {
    final state = _build(
      purpose: BusinessPurpose.advance,
      advanceSummary: const AdvanceSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 0),
        outstanding: Money(minorUnits: 10000),
        isClosed: false,
      ),
    );

    final action = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.advance,
    );
    expect(action.route, '/transaction/child/advance');
    expect(action.enabled, isTrue);
  });

  for (final management in AdvanceManagement.values) {
    test('routes ${management.name} advance transaction to edit', () {
      final state = _build(
        purpose: BusinessPurpose.advance,
        parentTransactionId: null,
        ownership: advanceOwnership(
          management: management,
          ownerId: management == AdvanceManagement.itemized
              ? 'child'
              : 'receivable',
          scenario: AdvanceScenario.aa,
        ),
      );

      expect(state.behavior.editRoute, '/transaction/child/edit');
      final edit = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(edit.enabled, isTrue);
    });
  }

  for (final scenario in [AdvanceScenario.aa, AdvanceScenario.reimbursement]) {
    test('account-managed ${scenario.name} advance exposes refund without '
        'itemized receipt', () {
      final state = _build(
        purpose: BusinessPurpose.advance,
        parentTransactionId: null,
        advanceSummary: const AdvanceSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 0),
          outstanding: Money(minorUnits: 10000),
          isClosed: false,
        ),
        ownership: advanceOwnership(
          management: AdvanceManagement.account,
          ownerId: 'receivable',
          scenario: scenario,
        ),
      );

      expect(state.advance, isNull);
      final refund = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.refund,
      );
      expect(refund.enabled, isTrue);
      expect(refund.route, '/transaction/child/refund');
      expect(
        state.actionButtons.any(
          (button) => button.kind == DetailActionKind.advance,
        ),
        isFalse,
      );
      expect(
        state.actionButtons.any(
          (button) => button.kind == DetailActionKind.edit,
        ),
        isTrue,
      );
    });
  }

  for (final scenario in [
    (AdvanceScenario.aa, 'AA收回'),
    (AdvanceScenario.onBehalf, '代付收回'),
    (AdvanceScenario.reimbursement, '报销'),
  ]) {
    test('labels advance action for ${scenario.$1.name}', () {
      final state = _build(
        purpose: BusinessPurpose.advance,
        advanceSummary: const AdvanceSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 0),
          outstanding: Money(minorUnits: 10000),
          isClosed: false,
        ),
        ownership: advanceOwnership(
          management: AdvanceManagement.itemized,
          ownerId: 'child',
          scenario: scenario.$1,
        ),
      );

      final action = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.advance,
      );
      expect(action.label, scenario.$2);
    });
  }

  for (final scenario in [
    (AdvanceScenario.aa, '应收账户'),
    (AdvanceScenario.onBehalf, '应收账户'),
    (AdvanceScenario.reimbursement, '报销账户'),
  ]) {
    test('labels advance receivable account for ${scenario.$1.name}', () {
      final state = _build(
        purpose: BusinessPurpose.advance,
        parentTransactionId: null,
        advanceSummary: const AdvanceSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 0),
          outstanding: Money(minorUnits: 10000),
          isClosed: false,
        ),
        counterpart: const TransactionLine(
          id: 'receivable-line',
          transactionId: 'child',
          lineNo: 2,
          role: TransactionRole.receivable,
          accountId: 'receivable',
          amount: Money(minorUnits: 10000),
        ),
        ownership: advanceOwnership(
          management: AdvanceManagement.itemized,
          ownerId: 'child',
          scenario: scenario.$1,
        ),
      );

      expect(state.accountRows.map((row) => row.label), ['收支账户', scenario.$2]);
    });
  }

  test('shows refund and advance information for the same advance', () {
    final state = _build(
      purpose: BusinessPurpose.advance,
      parentTransactionId: null,
      refundedTotal: const Money(minorUnits: 2000),
      advanceSummary: const AdvanceSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 4000),
        outstanding: Money(minorUnits: 4000),
        isClosed: false,
      ),
      children: [
        _child(
          id: 'refund',
          purpose: BusinessPurpose.refund,
          amountMinor: 2000,
        ),
        _child(
          id: 'receipt',
          purpose: BusinessPurpose.advanceCollection,
          amountMinor: 4000,
        ),
      ],
    );

    expect(state.refund?.refundedTotal, const Money(minorUnits: 2000));
    expect(state.refund?.items.map((item) => item.id), ['refund']);
    expect(state.advance?.summaryText, '已收 40.00 / 应收 100.00');
    expect(state.advance?.items.map((item) => item.id), ['receipt']);
  });

  test('opens a zero-receipt advance settlement from the parent', () {
    final state = _build(
      purpose: BusinessPurpose.advance,
      parentTransactionId: null,
      advanceSummary: const AdvanceSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 0),
        outstanding: Money(minorUnits: 0),
        isClosed: true,
      ),
      children: [
        _child(
          id: 'zero-close',
          purpose: BusinessPurpose.advanceSettlement,
          amountMinor: 0,
        ),
      ],
    );

    expect(state.advance?.hasActivity, isTrue);
    expect(state.advance?.items.map((item) => item.id), ['zero-close']);
  });

  test('keeps advance close editable while group is closed', () {
    final state = _build(
      purpose: BusinessPurpose.advanceSettlement,
      advanceSummary: const AdvanceSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 10000),
        outstanding: Money(minorUnits: 0),
        isClosed: true,
      ),
    );

    expect(state.behavior.editRoute, '/transaction/child/advance/edit');
    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(edit.enabled, isTrue);
  });

  test(
    'does not fall back to expense edit for unsupported balance adjustment',
    () {
      final state = _build(purpose: BusinessPurpose.balanceAdjustment);

      expect(state.behavior.editRoute, isNull);
      final edit = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(edit.enabled, isFalse);
    },
  );

  test('shows expense-like reporting controls for bad debt', () {
    final state = _build(purpose: BusinessPurpose.badDebt);

    expect(state.showExcludeStats, isTrue);
    expect(state.showExcludeBudget, isTrue);
  });

  test('shows income-like reporting controls for debt relief', () {
    final state = _build(purpose: BusinessPurpose.debtRelief);

    expect(state.showExcludeStats, isTrue);
    expect(state.showExcludeBudget, isTrue);
  });

  test('only top-level detail allows changing reporting flags', () {
    final parent = _build(
      purpose: BusinessPurpose.transfer,
      parentTransactionId: null,
    );
    final child = _build(purpose: BusinessPurpose.refund);
    expect(parent.canEditReportingFlags, isTrue);
    expect(child.canEditReportingFlags, isFalse);
    expect(child.showExcludeStats, isTrue);
    expect(child.showExcludeBudget, isTrue);
  });

  test('uses fund accounts for lending payment account edits', () {
    final state = _build(purpose: BusinessPurpose.lending);

    final paymentAccount = state.accountRows.singleWhere(
      (row) => row.label == '付款账户',
    );
    expect(paymentAccount.label, '付款账户');
    expect(paymentAccount.editPurpose, AccountSelectionPurpose.fund);
  });

  test('leaves multi-account income to the allocation breakdown', () {
    final state = _build(
      purpose: BusinessPurpose.dailyIncome,
      parentTransactionId: null,
      additionalLines: const [
        TransactionLine(
          id: 'second-account-line',
          transactionId: 'child',
          lineNo: 2,
          role: TransactionRole.settlementIn,
          accountId: 'bank',
          amount: Money(minorUnits: 500),
        ),
      ],
    );

    expect(state.accountRows, isEmpty);
  });
}

TransactionDetailLoaded _build({
  required BusinessPurpose purpose,
  String? parentTransactionId = 'parent',
  Money? refundedTotal,
  AdvanceSummary? advanceSummary,
  List<TransactionReadModel> children = const [],
  TransactionLine? counterpart,
  Iterable<TransactionLine> additionalLines = const [],
  TransactionOwnership? ownership,
}) {
  final detail = TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'child',
      parentTransactionId: parentTransactionId,
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 7, 23),
      primaryAmount:
          advanceSummary?.advanceAmount ??
          (purpose == BusinessPurpose.advance
              ? const Money(minorUnits: 10000)
              : const Money(minorUnits: 1000)),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: ownership,
    ),
    createdAt: DateTime(2026, 7, 23),
    lines: [
      ?counterpart,
      TransactionLine(
        id: 'account-line',
        transactionId: 'child',
        lineNo: 1,
        role: switch (purpose) {
          BusinessPurpose.dailyExpense ||
          BusinessPurpose.debtRepayment ||
          BusinessPurpose.lending => TransactionRole.settlementOut,
          BusinessPurpose.badDebt => TransactionRole.receivable,
          BusinessPurpose.debtRelief => TransactionRole.liability,
          _ => TransactionRole.settlementIn,
        },
        accountId: 'cash',
        amount: const Money(minorUnits: 1000),
      ),
      ...additionalLines,
    ],
    children: children,
    refundSummary: refundedTotal == null
        ? null
        : RefundSummary(
            refundedTotal: refundedTotal,
            originalCategoryAllocations: const [],
            refundedCategoryAllocations: const [],
          ),
    advanceSummary: advanceSummary,
  );
  final parentDetail = advanceSummary == null
      ? null
      : TransactionReadModel(
          id: 'parent',
          businessPurpose: BusinessPurpose.advance,
          occurredAt: DateTime(2026, 7, 22),
          primaryAmount: advanceSummary.advanceAmount,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          advanceSummary: advanceSummary,
          children: [
            if (advanceSummary.isClosed)
              TransactionReadModel(
                id: 'close',
                parentTransactionId: 'parent',
                businessPurpose: BusinessPurpose.advanceSettlement,
                occurredAt: DateTime(2026, 7, 22),
                primaryAmount: advanceSummary.receivedAmount,
                isExcludedFromStats: false,
                isExcludedFromBudget: false,
              ),
          ],
        );
  final accounts = <String, Account>{
    'receivable': Account(
      id: 'receivable',
      name: '应收款',
      type: AccountType.asset,
      subtype: AccountSubtype.receivable,
      iconKey: 'receivable',
      balance: Money.zero(),
    ),
    'loan': Account(
      id: 'loan',
      name: '借款',
      type: AccountType.liability,
      subtype: AccountSubtype.loan,
      iconKey: 'loan',
      balance: Money.zero(),
    ),
    'cash': Account(
      id: 'cash',
      name: '现金',
      type: AccountType.asset,
      balance: Money.zero(),
    ),
    'expense': Account(
      id: 'expense',
      name: '支出',
      type: AccountType.expense,
      balance: Money.zero(),
    ),
  };
  return buildTransactionDetailLoadedState(
        transactionId: 'child',
        detail: detail,
        parentDetail: parentDetail,
        accountLookup: AccountLookup(accounts),
      )
      as TransactionDetailLoaded;
}

TransactionReadModel _child({
  required String id,
  required BusinessPurpose purpose,
  required int amountMinor,
}) {
  return TransactionReadModel(
    id: id,
    parentTransactionId: 'child',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 7, 23),
    primaryAmount: Money(minorUnits: amountMinor),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    impactsByAccountId: const {},
    lines: [
      TransactionLine(
        id: '$id-settlement',
        transactionId: id,
        lineNo: 1,
        role: TransactionRole.settlementIn,
        accountId: 'cash',
        amount: Money(minorUnits: amountMinor),
      ),
    ],
  );
}
