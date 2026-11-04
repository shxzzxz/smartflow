import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/widget/business/transaction/transaction_avatar_kind.dart';
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
      businessItem: _amortizationItem(
        factKind: AmortizationTransactionFactKind.initial,
      ),
      businessActivity: _amortizationActivity(
        originalAmount: const Money(minorUnits: 1000),
        remainingAmount: const Money(minorUnits: 1000),
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
      businessItem: _amortizationItem(
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

  for (final factKind in [
    AmortizationTransactionFactKind.terminationRecognition,
    AmortizationTransactionFactKind.terminationReturn,
  ]) {
    test(
      'amortization ${factKind.name} remains editable from its transaction',
      () {
        final state = _build(
          purpose: BusinessPurpose.dailyExpense,
          parentTransactionId: null,
          businessItem: _amortizationItem(
            factKind: factKind,
            terminationId: 'termination',
          ),
          amortizationStatus: AmortizationStatus.terminated,
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
      },
    );
  }

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

    expect(state.businessModules, isEmpty);
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
      businessItem: InstallmentBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: installmentOwnerType,
          id: 'contract-1',
        ),
        itemKey: const BusinessActivityItemKey(
          type: installmentOwnerType,
          id: 'contract-1',
        ),
        role: BusinessActivityItemRole.origin,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        installmentType: InstallmentType.purchase,
        factKind: InstallmentTransactionFactKind.purchase,
      ),
      businessActivity: _installmentActivity(
        transactionId: 'child',
        remainingPrincipal: const Money(minorUnits: 6000),
      ),
    );

    final module = state.businessModules.single as DetailBusinessLinkModule;
    expect(module.title, '分期合同');
    expect(module.summary, '消费分期 · 已还 1/3 · 剩余本金 60.00');
    expect(module.route, '/installments/contract-1');
  });

  test('non-entry installment refund has no business module', () {
    final state = _build(
      purpose: BusinessPurpose.refund,
      parentTransactionId: null,
      businessItem: InstallmentBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: installmentOwnerType,
          id: 'contract-1',
        ),
        itemKey: const BusinessActivityItemKey.transaction('child'),
        role: BusinessActivityItemRole.followUp,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        installmentType: InstallmentType.purchase,
        factKind: InstallmentTransactionFactKind.refund,
      ),
    );

    expect(state.businessModules, isEmpty);
  });

  test('amortization refund stays local without plan module', () {
    final state = _build(
      purpose: BusinessPurpose.transfer,
      parentTransactionId: null,
      businessItem: _amortizationItem(
        factKind: AmortizationTransactionFactKind.refund,
        categoryId: 'food',
        refundId: 'refund',
      ),
    );

    expect(state.businessModules, isEmpty);
    expect(state.hero.title, '摊销退款');
    expect(state.hero.iconKey, isNull);
    expect(state.hero.avatarKind, TransactionAvatarKind.amortizationRefund);
    expect(state.hero.preferCategoryArtwork, isFalse);
  });

  for (final scenario in [
    (
      AmortizationTransactionFactKind.recognition,
      '第 2 期确认',
      TransactionAvatarKind.amortizationRecognition,
    ),
    (
      AmortizationTransactionFactKind.terminationRecognition,
      '终止确认',
      TransactionAvatarKind.amortizationTermination,
    ),
    (
      AmortizationTransactionFactKind.terminationReturn,
      '终止退还',
      TransactionAvatarKind.amortizationTermination,
    ),
  ]) {
    test('non-entry ${scenario.$1.name} uses business item icon', () {
      final state = _build(
        purpose: BusinessPurpose.dailyExpense,
        parentTransactionId: null,
        businessItem: _amortizationItem(
          factKind: scenario.$1,
          occurrencePeriodSequence: 2,
          categoryId: 'food',
          terminationId: 'termination',
        ),
      );

      expect(state.businessModules, isEmpty);
      expect(state.hero.title, scenario.$2);
      expect(state.hero.iconKey, isNull);
      expect(state.hero.avatarKind, scenario.$3);
      expect(state.hero.preferCategoryArtwork, isFalse);
    });
  }

  test('advance collection uses its own title and icon', () {
    final state = _build(
      purpose: BusinessPurpose.advanceCollection,
      parentTransactionId: null,
      businessItem: AdvanceBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: orchestrationAdvanceOwnerType,
          id: 'advance',
        ),
        itemKey: const BusinessActivityItemKey.transaction('child'),
        role: BusinessActivityItemRole.followUp,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        factKind: AdvanceTransactionFactKind.collection,
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.itemized,
      ),
    );

    expect(state.hero.title, '垫付到账');
    expect(state.hero.iconKey, isNull);
    expect(state.hero.avatarKind, TransactionAvatarKind.advanceCollection);
    expect(state.hero.preferCategoryArtwork, isFalse);
  });

  test(
    'amortization business module opens the plan and allows plan deletion',
    () {
      final state = _build(
        purpose: BusinessPurpose.dailyExpense,
        parentTransactionId: null,
        businessItem: _amortizationItem(
          planId: 'plan-1',
          factKind: AmortizationTransactionFactKind.initial,
          categoryId: 'insurance',
        ),
        businessActivity: _amortizationActivity(
          planId: 'plan-1',
          originalAmount: const Money(minorUnits: 10000),
          recognizedAmount: const Money(minorUnits: 2000),
          remainingAmount: const Money(minorUnits: 8000),
          postedPeriodCount: 1,
          totalPeriodCount: 5,
          categoryId: 'insurance',
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
      businessItem: _amortizationItem(
        factKind: AmortizationTransactionFactKind.initial,
      ),
      amortizationStatus: AmortizationStatus.terminated,
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
      businessItem: RepaymentBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: creditRepaymentOwnerType,
          id: 'repayment-1',
        ),
        itemKey: const BusinessActivityItemKey(
          type: creditRepaymentOwnerType,
          id: 'repayment-1',
        ),
        role: BusinessActivityItemRole.origin,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        repaymentId: 'repayment-1',
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: 'bill-1',
      ),
      businessActivity: _repaymentActivity(transactionId: 'child'),
    );

    final module = state.businessModules.single as DetailBusinessLinkModule;
    expect(module.summary, '账单还款 · 账单');
    expect(module.route, '/bills/bill-1');
    expect(
      state.behavior.editRoute,
      '/repayments/repayment-1/edit?transactionId=child',
    );
  });

  test('unattributed repayment remains an account activity entry', () {
    final state = _build(
      purpose: BusinessPurpose.debtRepayment,
      parentTransactionId: null,
      businessItem: RepaymentBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: creditRepaymentOwnerType,
          id: 'repayment-2',
        ),
        itemKey: const BusinessActivityItemKey(
          type: creditRepaymentOwnerType,
          id: 'repayment-2',
        ),
        role: BusinessActivityItemRole.origin,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        repaymentId: 'repayment-2',
        repaymentType: RepaymentType.unattributed,
        targetType: RepaymentTargetType.account,
        targetId: 'credit-account',
      ),
      businessActivity: _repaymentActivity(
        transactionId: 'child',
        repaymentId: 'repayment-2',
        repaymentType: RepaymentType.unattributed,
        targetType: RepaymentTargetType.account,
      ),
    );

    final module = state.businessModules.single as DetailBusinessLinkModule;
    expect(module.summary, '未归属还款 · 账户');
    expect(module.route, '/account/credit-account');
  });

  test('prepayment stays local while retaining repayment actions', () {
    final state = _build(
      purpose: BusinessPurpose.debtRepayment,
      parentTransactionId: null,
      businessItem: RepaymentBusinessActivityItem(
        activityKey: const BusinessActivityKey(
          type: installmentOwnerType,
          id: 'contract-1',
        ),
        itemKey: const BusinessActivityItemKey(
          type: creditRepaymentOwnerType,
          id: 'prepayment',
        ),
        role: BusinessActivityItemRole.followUp,
        occurredAt: DateTime(2026, 1, 15),
        projections: const [
          BusinessActivityItemProjection(transactionId: 'child'),
        ],
        repaymentId: 'prepayment',
        repaymentType: RepaymentType.prepayment,
        targetType: RepaymentTargetType.contract,
        targetId: 'contract-1',
      ),
    );

    expect(state.businessModules, isEmpty);
    expect(state.hero.title, '提前还款');
    expect(state.hero.avatarKind, TransactionAvatarKind.prepayment);
    expect(state.behavior.deletePermission, isA<DetailEditAllowed>());
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
  BusinessActivityItem? businessItem,
  BusinessActivityReadModel? businessActivity,
  AmortizationStatus amortizationStatus = AmortizationStatus.active,
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
    'food': Account(
      id: 'food',
      name: '餐饮',
      type: AccountType.expense,
      iconKey: 'meal',
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
  final item =
      businessItem ??
      (resolvedAdvanceCase != null
          ? AdvanceBusinessActivityItem(
              activityKey: BusinessActivityKey(
                type: orchestrationAdvanceOwnerType,
                id: resolvedAdvanceCase.id,
              ),
              itemKey: BusinessActivityItemKey(
                type: orchestrationAdvanceOwnerType,
                id: resolvedAdvanceCase.id,
              ),
              role: BusinessActivityItemRole.origin,
              occurredAt: detail.occurredAt,
              projections: [
                BusinessActivityItemProjection(transactionId: detail.id),
              ],
              factKind: AdvanceTransactionFactKind.advance,
              scenario: resolvedAdvanceCase.scenario,
              trackingMode: resolvedAdvanceCase.trackingMode,
            )
          : null);
  final activity =
      businessActivity ??
      (resolvedAdvanceCase != null && advanceSummary != null
          ? _advanceActivity(
              transaction: detail,
              summary: advanceSummary,
              caseId: resolvedAdvanceCase.id,
              scenario: resolvedAdvanceCase.scenario,
              trackingMode: resolvedAdvanceCase.trackingMode,
            )
          : null);
  final context = TransactionDetailContext(
    transaction: detail,
    parentFacts: parentTransactionId != null
        ? TransactionParentFacts(
            isExcludedFromStats: false,
            isExcludedFromBudget: false,
            isAdvanceClosed: advanceSummary?.isClosed ?? false,
          )
        : null,
    businessItem: item,
    isAmortizationTerminated:
        amortizationStatus == AmortizationStatus.terminated,
  );
  return buildTransactionDetailLoadedState(
        detail: TransactionDetailReadModel(
          context: context,
          businessActivity: activity,
        ),
        accountLookup: AccountLookup(accounts),
      )
      as TransactionDetailLoaded;
}

AmortizationBusinessActivityItem _amortizationItem({
  String transactionId = 'child',
  String planId = 'plan',
  AmortizationKind kind = AmortizationKind.prepaidExpense,
  AmortizationTransactionFactKind factKind =
      AmortizationTransactionFactKind.initial,
  String? refundId,
  String? terminationId,
  int? occurrencePeriodSequence,
  String? categoryId = 'food',
}) {
  return AmortizationBusinessActivityItem(
    activityKey: BusinessActivityKey(
      type: orchestrationAmortizationOwnerType,
      id: planId,
    ),
    itemKey: switch (factKind) {
      AmortizationTransactionFactKind.initial => BusinessActivityItemKey(
        type: orchestrationAmortizationOwnerType,
        id: planId,
      ),
      AmortizationTransactionFactKind.refund => BusinessActivityItemKey(
        type: 'orchestration.amortization_refund',
        id: refundId!,
      ),
      AmortizationTransactionFactKind.terminationRecognition ||
      AmortizationTransactionFactKind.terminationReturn =>
        BusinessActivityItemKey(
          type: 'orchestration.amortization_termination',
          id: terminationId!,
        ),
      AmortizationTransactionFactKind.recognition =>
        BusinessActivityItemKey.transaction(transactionId),
    },
    role: factKind == AmortizationTransactionFactKind.initial
        ? BusinessActivityItemRole.origin
        : BusinessActivityItemRole.followUp,
    occurredAt: DateTime(2026, 1, 15),
    projections: [
      AmortizationTransactionProjection(
        transactionId: transactionId,
        factKind: factKind,
        occurrencePeriodSequence: occurrencePeriodSequence,
        localCategoryAllocations: [
          if (categoryId != null)
            AccountAmountAllocation(
              accountId: categoryId,
              amount: const Money(minorUnits: 1000),
            ),
        ],
      ),
    ],
    kind: kind,
    refundId: refundId,
    terminationId: terminationId,
  );
}

BusinessActivityReadModel _amortizationActivity({
  String transactionId = 'child',
  String planId = 'plan',
  AmortizationKind kind = AmortizationKind.prepaidExpense,
  AmortizationStatus status = AmortizationStatus.active,
  Money originalAmount = const Money(minorUnits: 1000),
  Money recognizedAmount = const Money(minorUnits: 0),
  Money remainingAmount = const Money(minorUnits: 1000),
  int postedPeriodCount = 0,
  int totalPeriodCount = 3,
  String? categoryId = 'food',
}) {
  final transaction = _activityTransaction(
    id: transactionId,
    ownerType: orchestrationAmortizationOwnerType,
    ownerId: planId,
  );
  final key = BusinessActivityKey(
    type: orchestrationAmortizationOwnerType,
    id: planId,
  );
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityCandidate(
      activityKey: key,
      displayTransactionId: transaction.id,
      activityAt: transaction.occurredAt,
    ),
    displayTransaction: transaction,
    summary: AmortizationBusinessActivitySummary(
      kind: kind,
      status: status,
      originalAmount: originalAmount,
      recognizedAmount: recognizedAmount,
      remainingAmount: remainingAmount,
      postedPeriodCount: postedPeriodCount,
      totalPeriodCount: totalPeriodCount,
      categoryAccountIds: [?categoryId],
    ),
  );
}

BusinessActivityReadModel _installmentActivity({
  required String transactionId,
  required Money remainingPrincipal,
}) {
  final transaction = _activityTransaction(
    id: transactionId,
    ownerType: installmentOwnerType,
    ownerId: 'contract-1',
  );
  final key = const BusinessActivityKey(
    type: installmentOwnerType,
    id: 'contract-1',
  );
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityCandidate(
      activityKey: key,
      displayTransactionId: transaction.id,
      activityAt: transaction.occurredAt,
    ),
    displayTransaction: transaction,
    summary: InstallmentBusinessActivitySummary(
      installmentType: InstallmentType.purchase,
      status: InstallmentContractStatus.active,
      principal: const Money(minorUnits: 10000),
      remainingPrincipal: remainingPrincipal,
      paidPeriodCount: 1,
      totalPeriodCount: 3,
    ),
  );
}

BusinessActivityReadModel _repaymentActivity({
  required String transactionId,
  String repaymentId = 'repayment-1',
  RepaymentType repaymentType = RepaymentType.bill,
  RepaymentTargetType targetType = RepaymentTargetType.bill,
}) {
  final transaction = _activityTransaction(
    id: transactionId,
    ownerType: creditRepaymentOwnerType,
    ownerId: repaymentId,
  );
  final key = BusinessActivityKey(
    type: creditRepaymentOwnerType,
    id: repaymentId,
  );
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityCandidate(
      activityKey: key,
      displayTransactionId: transaction.id,
      activityAt: transaction.occurredAt,
    ),
    displayTransaction: transaction,
    summary: RepaymentBusinessActivitySummary(
      repaymentType: repaymentType,
      targetType: targetType,
    ),
  );
}

BusinessActivityReadModel _advanceActivity({
  required TransactionReadModel transaction,
  required AdvanceSummary summary,
  required String caseId,
  required AdvanceScenario scenario,
  required AdvanceTrackingMode trackingMode,
}) {
  final key = BusinessActivityKey(
    type: orchestrationAdvanceOwnerType,
    id: caseId,
  );
  final ownedTransaction = TransactionReadModel(
    id: transaction.id,
    businessPurpose: transaction.businessPurpose,
    occurredAt: transaction.occurredAt,
    postedAt: transaction.postedAt,
    primaryAmount: transaction.primaryAmount,
    ownership: TransactionOwnership(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: caseId,
    ),
    isExcludedFromStats: transaction.isExcludedFromStats,
    isExcludedFromBudget: transaction.isExcludedFromBudget,
    children: transaction.children,
    advanceSummary: summary,
    lines: transaction.lines,
  );
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityCandidate(
      activityKey: key,
      displayTransactionId: ownedTransaction.id,
      activityAt: ownedTransaction.occurredAt,
    ),
    displayTransaction: ownedTransaction,
    summary: AdvanceBusinessActivitySummary(
      scenario: scenario,
      trackingMode: trackingMode,
      outstanding: summary.outstanding,
      isClosed: summary.isClosed,
    ),
  );
}

TransactionReadModel _activityTransaction({
  required String id,
  required String ownerType,
  required String ownerId,
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.transfer,
    occurredAt: DateTime(2026, 7, 23),
    primaryAmount: const Money(minorUnits: 1000),
    ownership: TransactionOwnership(ownerType: ownerType, ownerId: ownerId),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
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
