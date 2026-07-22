import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state_builder.dart';

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
}

TransactionDetailLoaded _build({
  required BusinessPurpose purpose,
  String? parentTransactionId = 'parent',
  Money? refundedTotal,
  ReimbursementSummary? reimbursementSummary,
  List<TransactionListReadModel> children = const [],
}) {
  final entries = [
    Entry(
      id: 'cash-entry',
      transactionId: 'child',
      accountId: 'cash',
      direction: EntryDirection.debit,
      amount: const Money(minorUnits: 1000),
    ),
    Entry(
      id: 'offset-entry',
      transactionId: 'child',
      accountId: 'expense',
      direction: EntryDirection.credit,
      amount: const Money(minorUnits: 1000),
    ),
  ];
  final detail = TransactionDetail(
    transaction: Transaction(
      id: 'child',
      parentTransactionId: parentTransactionId,
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 7, 23),
      primaryAmount: const Money(minorUnits: 1000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      entries: entries,
    ),
    createdAt: DateTime(2026, 7, 23),
    details: const [],
    entries: entries,
    children: children,
    refundedTotal: refundedTotal,
    reimbursementSummary: reimbursementSummary,
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
        accountLookup: AccountLookup(accounts),
      )
      as TransactionDetailLoaded;
}

TransactionListReadModel _child({
  required String id,
  required BusinessPurpose purpose,
  required int amountMinor,
}) {
  return TransactionListReadModel(
    id: id,
    parentTransactionId: 'child',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 7, 23),
    primaryAmount: Money(minorUnits: amountMinor),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    entries: const [],
    details: const [],
  );
}
