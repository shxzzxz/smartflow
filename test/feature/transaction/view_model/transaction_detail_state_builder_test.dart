import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail/transaction_detail_state_builder.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import '../../../helper/advance_ownership_fixtures.dart';

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

  test('amortization initial exposes refund, terminate and plan edit', () {
    final state = _build(
      purpose: BusinessPurpose.dailyExpense,
      parentTransactionId: null,
      businessOwner: AmortizationTransactionBusinessContext(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan',
        initialTransactionId: 'child',
        kind: AmortizationKind.prepaidExpense,
        status: AmortizationStatus.active,
        originalAmount: Money(minorUnits: 1000),
        recognizedAmount: Money.zero(),
        remainingAmount: Money(minorUnits: 1000),
        postedPeriodCount: 0,
        totalPeriodCount: 3,
        factKind: AmortizationTransactionFactKind.initial,
      ),
    );

    final refund = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.refund,
    );
    final terminate = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.amortizationTermination,
    );
    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(refund.route, '/transaction/child/refund');
    expect(terminate.route, '/transaction/child/amortization-terminate');
    expect(edit.route, '/transaction/child/edit');
    expect(state.canEditReportingFlags, isTrue);
    expect(state.behavior.canEditNote, isA<DetailEditAllowed>());
    expect(state.behavior.canEditOccurredAt, isA<DetailEditAllowed>());
    expect(state.behavior.canEditPostedAt, isA<DetailEditAllowed>());
  });

  test('amortization refund routes to refund edit and refund deletion', () {
    final state = _build(
      purpose: BusinessPurpose.transfer,
      parentTransactionId: null,
      businessOwner: AmortizationTransactionBusinessContext(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan',
        initialTransactionId: 'initial',
        kind: AmortizationKind.prepaidExpense,
        status: AmortizationStatus.active,
        originalAmount: Money(minorUnits: 10000),
        recognizedAmount: Money.zero(),
        remainingAmount: Money(minorUnits: 10000),
        postedPeriodCount: 0,
        totalPeriodCount: 3,
        factKind: AmortizationTransactionFactKind.refund,
        refundId: 'refund',
      ),
    );

    expect(state.behavior.editRoute, '/transaction/child/refund/edit');
    expect(state.behavior.deleteMessage, contains('这笔摊销退款'));
    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(
      state.actionButtons.any(
        (button) => button.kind == DetailActionKind.refund,
      ),
      isFalse,
    );
    expect(
      state.actionButtons.any(
        (button) => button.kind == DetailActionKind.amortizationTermination,
      ),
      isFalse,
    );
    expect(edit.route, '/transaction/child/refund/edit');
    expect(edit.enabled, isTrue);
  });

  test('amortization termination remains editable from its transaction', () {
    final state = _build(
      purpose: BusinessPurpose.dailyExpense,
      parentTransactionId: null,
      businessOwner: AmortizationTransactionBusinessContext(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan',
        initialTransactionId: 'initial',
        kind: AmortizationKind.prepaidExpense,
        status: AmortizationStatus.terminated,
        originalAmount: Money(minorUnits: 10000),
        recognizedAmount: Money(minorUnits: 10000),
        remainingAmount: Money.zero(),
        postedPeriodCount: 3,
        totalPeriodCount: 3,
        factKind: AmortizationTransactionFactKind.terminationRecognition,
        terminationId: 'termination',
      ),
    );

    expect(
      state.behavior.editRoute,
      '/transaction/child/amortization-terminate/edit',
    );
    expect(state.behavior.deleteMessage, contains('该笔摊销终止'));
    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(
      state.actionButtons.any(
        (button) => button.kind == DetailActionKind.refund,
      ),
      isFalse,
    );
    expect(
      state.actionButtons.any(
        (button) => button.kind == DetailActionKind.amortizationTermination,
      ),
      isFalse,
    );
    expect(edit.enabled, isTrue);
  });

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

  for (final management in AdvanceTrackingMode.values) {
    test('routes ${management.name} advance transaction to edit', () {
      final state = _build(
        purpose: BusinessPurpose.advance,
        parentTransactionId: null,
        ownership: advanceOwnership(
          management: management,
          ownerId: management == AdvanceTrackingMode.itemized
              ? 'child'
              : 'receivable',
          scenario: AdvanceScenario.aa,
        ),
        advanceCase: AdvanceCase(
          id: 'case',
          scenario: AdvanceScenario.aa,
          trackingMode: management,
          aaPeopleCount: management == AdvanceTrackingMode.itemized ? 2 : null,
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
          management: AdvanceTrackingMode.account,
          ownerId: 'receivable',
          scenario: scenario,
        ),
        advanceCase: AdvanceCase(
          id: 'case',
          scenario: scenario,
          trackingMode: AdvanceTrackingMode.account,
          receivableAccountId: 'receivable',
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
          management: AdvanceTrackingMode.itemized,
          ownerId: 'child',
          scenario: scenario.$1,
        ),
        advanceCase: AdvanceCase(
          id: 'case',
          scenario: scenario.$1,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: scenario.$1 == AdvanceScenario.aa ? 2 : null,
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
          management: AdvanceTrackingMode.itemized,
          ownerId: 'child',
          scenario: scenario.$1,
        ),
        advanceCase: AdvanceCase(
          id: 'case',
          scenario: scenario.$1,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: scenario.$1 == AdvanceScenario.aa ? 2 : null,
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

  test('composes installment facts into a business module', () {
    final state = _build(
      purpose: BusinessPurpose.dailyExpense,
      parentTransactionId: null,
      businessOwner: const InstallmentTransactionBusinessContext(
        ownerType: installmentOwnerType,
        ownerId: 'contract-1',
        installmentType: InstallmentType.purchase,
        status: InstallmentContractStatus.active,
        principal: Money(minorUnits: 10000),
        remainingPrincipal: Money(minorUnits: 6000),
        paidPeriodCount: 1,
        totalPeriodCount: 3,
      ),
    );

    final module = state.businessModules.single as DetailBusinessLinkModule;
    expect(module.title, '分期合同');
    expect(module.summary, '消费分期 · 已还 1/3 · 剩余本金 60.00');
    expect(module.route, '/installments/contract-1');
  });

  test(
    'amortization business module opens the plan and allows plan deletion',
    () {
      final state = _build(
        purpose: BusinessPurpose.dailyExpense,
        parentTransactionId: null,
        businessOwner: const AmortizationTransactionBusinessContext(
          ownerType: orchestrationAmortizationOwnerType,
          ownerId: 'plan-1',
          initialTransactionId: 'child',
          kind: AmortizationKind.prepaidExpense,
          status: AmortizationStatus.active,
          originalAmount: Money(minorUnits: 10000),
          recognizedAmount: Money(minorUnits: 2000),
          remainingAmount: Money(minorUnits: 8000),
          postedPeriodCount: 1,
          totalPeriodCount: 5,
          categoryAccountIds: ['insurance'],
        ),
      );

      final module = state.businessModules.single as DetailBusinessLinkModule;
      expect(module.route, '/amortizations/plan-1');
      expect(module.summary, '预付费用 · 进行中 · 已确认 1/5');
      expect(state.behavior.deletePermission, isA<DetailEditAllowed>());
      expect(state.hero.title, '保险');
      expect(state.hero.iconKey, 'shield');
    },
  );

  test('terminated amortization keeps deletion but rejects editing', () {
    final state = _build(
      purpose: BusinessPurpose.dailyExpense,
      parentTransactionId: null,
      businessOwner: const AmortizationTransactionBusinessContext(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan-1',
        initialTransactionId: 'child',
        kind: AmortizationKind.prepaidExpense,
        status: AmortizationStatus.terminated,
        originalAmount: Money(minorUnits: 10000),
        recognizedAmount: Money(minorUnits: 10000),
        remainingAmount: Money(minorUnits: 0),
        postedPeriodCount: 5,
        totalPeriodCount: 5,
      ),
    );

    final edit = state.actionButtons.singleWhere(
      (button) => button.kind == DetailActionKind.edit,
    );
    expect(edit.enabled, isFalse);
    expect(edit.deniedReason, '请先删除摊销终止');
    expect(state.behavior.deletePermission, isA<DetailEditAllowed>());
  });

  test('credit repayment business module opens its stable target', () {
    final state = _build(
      purpose: BusinessPurpose.debtRepayment,
      parentTransactionId: null,
      businessOwner: const RepaymentTransactionBusinessContext(
        ownerType: creditRepaymentOwnerType,
        ownerId: 'repayment-1',
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: 'bill-1',
      ),
    );

    final module = state.businessModules.single as DetailBusinessLinkModule;
    expect(module.summary, '账单还款 · 账单');
    expect(module.route, '/bills/bill-1');
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
  AdvanceCase? advanceCase,
  TransactionBusinessContext? businessOwner,
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
    'insurance': Account(
      id: 'insurance',
      name: '保险',
      type: AccountType.expense,
      iconKey: 'shield',
      balance: Money.zero(),
    ),
  };
  final resolvedAdvanceCase =
      advanceCase ??
      (purpose == BusinessPurpose.advance
          ? const AdvanceCase(
              id: 'default-case',
              scenario: AdvanceScenario.reimbursement,
              trackingMode: AdvanceTrackingMode.itemized,
            )
          : null);
  final owner =
      businessOwner ??
      (resolvedAdvanceCase != null
          ? AdvanceTransactionBusinessContext(
              ownerType: orchestrationAdvanceOwnerType,
              ownerId: resolvedAdvanceCase.id,
              scenario: resolvedAdvanceCase.scenario,
              trackingMode: resolvedAdvanceCase.trackingMode,
              advanceAmount:
                  advanceSummary?.advanceAmount ?? detail.primaryAmount,
              receivedAmount: advanceSummary?.receivedAmount ?? Money.zero(),
              outstanding: advanceSummary?.outstanding ?? detail.primaryAmount,
              isClosed: advanceSummary?.isClosed ?? false,
              aaPeopleCount: resolvedAdvanceCase.aaPeopleCount,
            )
          : ownership?.ownerType == orchestrationAmortizationOwnerType
          ? AmortizationTransactionBusinessContext(
              ownerType: ownership!.ownerType,
              ownerId: ownership.ownerId,
              initialTransactionId: detail.id,
              kind: AmortizationKind.prepaidExpense,
              status: AmortizationStatus.active,
              originalAmount: detail.primaryAmount,
              recognizedAmount: Money.zero(),
              remainingAmount: detail.primaryAmount,
              postedPeriodCount: 0,
              totalPeriodCount: 3,
            )
          : null);
  final context = TransactionDetailContext(
    transaction: detail,
    parentTransaction: parentDetail,
    currentGroup: TransactionDetailGroup(
      anchor: parentDetail ?? detail,
      children: (parentDetail ?? detail).children,
    ),
    anchorGroup: TransactionDetailGroup(
      anchor: parentDetail ?? detail,
      children: (parentDetail ?? detail).children,
    ),
    businessContext: owner,
  );
  return buildTransactionDetailLoadedState(
        context: context,
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
