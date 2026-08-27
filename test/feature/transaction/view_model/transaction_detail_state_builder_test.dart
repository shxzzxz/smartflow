import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state_builder.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test(
    'routes refund child to refund edit and locks it after reimbursement close',
    () {
      final state = _build(
        purpose: BusinessPurpose.refund,
        reimbursementSummary: const ReimbursementSummary(
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
      expect(edit.deniedReason, '报销已结束，请先删除结束报销');
      expect(state.behavior.canEditNote, isA<DetailEditDenied>());
    },
  );

  test(
    'routes open reimbursement receipt child to shared reimbursement edit',
    () {
      final state = _build(
        purpose: BusinessPurpose.reimbursementReceipt,
        reimbursementSummary: const ReimbursementSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 4000),
          outstanding: Money(minorUnits: 6000),
          isClosed: false,
        ),
      );

      expect(state.behavior.editRoute, '/transaction/child/reimbursement/edit');
      final edit = state.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(edit.enabled, isTrue);
    },
  );

  test('routes reimbursement action to the standalone reimbursement form', () {
    final state = _build(
      purpose: BusinessPurpose.reimbursementAdvance,
      reimbursementSummary: const ReimbursementSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 0),
        outstanding: Money(minorUnits: 10000),
        isClosed: false,
      ),
    );

    final action = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.reimbursement,
    );
    expect(action.route, '/transaction/child/reimbursement');
    expect(action.enabled, isTrue);
  });

  test('shows refund and reimbursement information for the same advance', () {
    final state = _build(
      purpose: BusinessPurpose.reimbursementAdvance,
      parentTransactionId: null,
      refundedTotal: const Money(minorUnits: 2000),
      reimbursementSummary: const ReimbursementSummary(
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
          purpose: BusinessPurpose.reimbursementReceipt,
          amountMinor: 4000,
        ),
      ],
    );

    expect(state.refund?.refundedTotal, const Money(minorUnits: 2000));
    expect(state.refund?.items.map((item) => item.id), ['refund']);
    expect(state.reimbursement?.summaryText, '已收 40.00 / 应收 100.00');
    expect(state.reimbursement?.items.map((item) => item.id), ['receipt']);
  });

  test('keeps reimbursement close editable while group is closed', () {
    final state = _build(
      purpose: BusinessPurpose.reimbursementClose,
      reimbursementSummary: const ReimbursementSummary(
        advanceAmount: Money(minorUnits: 10000),
        receivedAmount: Money(minorUnits: 10000),
        outstanding: Money(minorUnits: 0),
        isClosed: true,
      ),
    );

    expect(state.behavior.editRoute, '/transaction/child/reimbursement/edit');
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
    expect(state.showExcludeBudget, isFalse);
  });

  test('uses fund accounts for lending payment account edits', () {
    final state = _build(purpose: BusinessPurpose.lending);

    final paymentAccount = state.accountRows.single;
    expect(paymentAccount.label, '付款账户');
    expect(paymentAccount.editPurpose, AccountSelectionPurpose.fund);
  });
}

TransactionDetailLoaded _build({
  required BusinessPurpose purpose,
  String? parentTransactionId = 'parent',
  Money? refundedTotal,
  ReimbursementSummary? reimbursementSummary,
  List<TransactionReadModel> children = const [],
}) {
  final detail = TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'child',
      parentTransactionId: parentTransactionId,
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 7, 23),
      primaryAmount: reimbursementSummary?.advanceAmount ??
          (purpose == BusinessPurpose.reimbursementAdvance
              ? const Money(minorUnits: 10000)
              : const Money(minorUnits: 1000)),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 7, 23),
    lines: [
      TransactionLine(
        id: 'account-line', transactionId: 'child', lineNo: 1,
        role: switch (purpose) {
          BusinessPurpose.dailyExpense || BusinessPurpose.debtRepayment || BusinessPurpose.lending => TransactionRole.settlementOut,
          BusinessPurpose.badDebt => TransactionRole.receivable,
          BusinessPurpose.debtRelief => TransactionRole.liability,
          _ => TransactionRole.settlementIn,
        },
        accountId: 'cash', amount: const Money(minorUnits: 1000),
      ),
    ],
    children: children,
  );
  final parentDetail = reimbursementSummary == null ? null : TransactionReadModel(
    id: 'parent', businessPurpose: BusinessPurpose.reimbursementAdvance,
    occurredAt: DateTime(2026, 7, 22), primaryAmount: reimbursementSummary.advanceAmount,
    isExcludedFromStats: false, isExcludedFromBudget: false,
    children: [
      if (reimbursementSummary.isClosed)
        TransactionReadModel(id: 'close', parentTransactionId: 'parent', businessPurpose: BusinessPurpose.reimbursementClose, occurredAt: DateTime(2026, 7, 22), primaryAmount: reimbursementSummary.receivedAmount, isExcludedFromStats: false, isExcludedFromBudget: false),
    ],
  );
  final accounts = <String, Account>{
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
