import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/refund/refund_form_view_model.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/advance/advance_form_view_model.dart';
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

    expect(
      outcome,
      isA<SubmitSuccess>(),
      reason: outcome is SubmitFailure ? outcome.error.message : null,
    );
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
    'routes a purchase refund through consumption installment refunds',
    () async {
      final refunds = _FakeConsumptionInstallmentService();
      final container = _container(
        purchaseParent: true,
        consumptionRefunds: refunds,
      );
      final provider = refundFormViewModelProvider('parent');
      final state = await container.read(provider.future);

      expect(state.installmentContractId, 'purchase-contract');
      expect(state.installmentLiabilityAccountId, 'credit');
      expect(state.refundablePrincipal, const Money(minorUnits: 10000));

      container.read(provider.notifier).setSettlementAllocations(const [
        AccountAmountAllocation(
          accountId: 'credit',
          amount: Money(minorUnits: 10000),
        ),
      ]);
      final outcome = await container
          .read(provider.notifier)
          .submit(amountText: '100', noteText: 'return');

      expect(outcome, isA<SubmitSuccess>());
      final command = refunds.createCommands.single;
      expect(command.contractId, 'purchase-contract');
      expect(command.parentTransactionId, 'parent');
      expect(command.settlementAllocations.single.accountId, 'credit');
    },
  );

  test(
    'refreshes the liability refund limit when the business date changes',
    () async {
      final refunds = _FakeConsumptionInstallmentService(
        limitForDate: (date) => date.day == 1
            ? const Money(minorUnits: 6000)
            : const Money(minorUnits: 10000),
      );
      final container = _container(
        purchaseParent: true,
        consumptionRefunds: refunds,
      );
      final provider = refundFormViewModelProvider('parent');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      container.read(provider.notifier).setOccurredAt(DateTime(2026, 7, 1));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(provider).requireValue;
      expect(state.refundablePrincipal, const Money(minorUnits: 6000));
      expect(state.refundLimitLoading, isFalse);
    },
  );

  test('blocks liability allocation above the refundable principal', () async {
    final refunds = _FakeConsumptionInstallmentService();
    final container = _container(
      purchaseParent: true,
      consumptionRefunds: refunds,
    );
    final provider = refundFormViewModelProvider('parent');
    await container.read(provider.future);
    container.read(provider.notifier).setSettlementAllocations(const [
      AccountAmountAllocation(
        accountId: 'credit',
        amount: Money(minorUnits: 10001),
      ),
    ]);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '100.01', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    expect(refunds.createCommands, isEmpty);
  });

  test('refreshes the installment plan after a covering refund', () async {
    final refunds = _FakeConsumptionInstallmentService();
    var activityLoads = 0;
    final container = _container(
      purchaseParent: true,
      consumptionRefunds: refunds,
      scheduleLoader: (_) async => [
        _schedule(principal: refunds.createCommands.isEmpty ? 10000 : 0),
      ],
      activityLoader: (_) async {
        activityLoads++;
        return const [];
      },
    );
    final provider = installmentDetailProvider('purchase-contract');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    expect(
      (await container.read(
        provider.future,
      ))!.schedules.single.expectedPrincipal,
      const Money(minorUnits: 10000),
    );
    final activitiesProvider = installmentActivitiesProvider(
      'purchase-contract',
    );
    final activitiesSubscription = container.listen(
      activitiesProvider,
      (_, _) {},
    );
    addTearDown(activitiesSubscription.close);
    await container.read(activitiesProvider.future);
    expect(activityLoads, 1);

    final refundProvider = refundFormViewModelProvider('parent');
    await container.read(refundProvider.future);
    container.read(refundProvider.notifier).setSettlementAllocations(const [
      AccountAmountAllocation(
        accountId: 'credit',
        amount: Money(minorUnits: 10000),
      ),
    ]);
    final outcome = await container
        .read(refundProvider.notifier)
        .submit(amountText: '100', noteText: 'return');

    expect(outcome, isA<SubmitSuccess>());
    expect(
      (await container.read(
        provider.future,
      ))!.schedules.single.expectedPrincipal,
      Money.zero(),
    );
    await container.read(activitiesProvider.future);
    expect(activityLoads, 2);
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

  test('creates an amortization refund through the refund form', () async {
    final plan = _amortizationPlan();
    final service = _FakeAmortizationPlanService();
    final container = _amortizationContainer(plan: plan, service: service);
    final provider = refundFormViewModelProvider('amortization-tx');

    final state = await container.read(provider.future);

    expect(state.amortizationPlanId, plan.id);
    expect(state.remaining, const Money(minorUnits: 30000));
    expect(state.availableCategoryAllocations.single.accountId, 'expense');
    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '100', noteText: 'partial return');

    expect(outcome, isA<SubmitSuccess>());
    final command = service.refundCommands.single;
    expect(command.planId, plan.id);
    expect(command.categoryAllocations.single.amount, _money(10000));
    expect(command.settlementAllocations.single.accountId, 'cash');
    expect(command.note, 'partial return');
  });

  test('submits an amortization termination with zero refund', () async {
    final plan = _amortizationPlan();
    final service = _FakeAmortizationPlanService();
    final container = _amortizationContainer(plan: plan, service: service);
    final provider = refundFormViewModelProvider(
      'amortization-tx',
      amortizationTermination: true,
    );

    final state = await container.read(provider.future);

    expect(state.amortizationTermination, isTrue);
    expect(state.remaining, const Money(minorUnits: 30000));
    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    final command = service.terminationCommands.single;
    expect(command.planId, plan.id);
    expect(command.categoryReturnAllocations, isEmpty);
    expect(command.settlementAllocations, isEmpty);
  });

  test('edits an amortization refund through the shared refund form', () async {
    final created = _amortizationPlan();
    final plan = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'expense',
          amount: _money(5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(5000),
        ),
        transferTransactionId: 'refund-tx',
      ),
    );
    final service = _FakeAmortizationPlanService();
    final detail = _amortizationDetail(
      plan: plan,
      transactionId: 'refund-tx',
      occurredAt: DateTime(2026, 1, 20),
      amount: _money(5000),
    );
    final container = _amortizationContainer(
      plan: plan,
      service: service,
      transactionId: 'refund-tx',
      transactionDetail: detail,
    );
    final provider = refundFormViewModelProvider('refund-tx', editing: true);

    final state = await container.read(provider.future);

    expect(state.amortizationRefundId, 'refund');
    expect(state.amountText, '50');
    expect(
      state.categoryAllocations?.single.amount,
      const Money(minorUnits: 5000),
    );
    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '60', noteText: 'updated');

    expect(
      outcome,
      isA<SubmitSuccess>(),
      reason: outcome is SubmitFailure ? outcome.error.message : null,
    );
    final command = service.refundEditCommands.single;
    expect(command.refundId, 'refund');
    expect(command.categoryAllocations.single.amount, _money(6000));
    expect(command.occurredAt, DateTime(2026, 1, 20));
    expect(command.note, isA<PatchSet<String?>>());
  });

  test('terminated amortization cannot be edited after termination', () async {
    final created = _amortizationPlan();
    final terminated = created.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: created.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [],
        settlementAllocations: const [],
        recognitionTransactionId: 'termination-entry',
      ),
      periods: created.periods,
    );
    final container = _amortizationContainer(
      plan: terminated,
      service: _FakeAmortizationPlanService(),
    );

    final state = await container.read(
      refundFormViewModelProvider('amortization-tx').future,
    );

    expect(state.status, RefundFormStatus.notEditable);
    expect(state.message, '摊销计划已终止，请先删除摊销终止');
  });

  test('edits the existing amortization termination', () async {
    final created = _amortizationPlan();
    final terminated = created.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: created.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: singleAllocation(
          accountId: 'expense',
          amount: _money(5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(5000),
        ),
        recognitionTransactionId: 'termination-entry',
        returnTransactionId: 'termination-return',
      ),
      periods: [for (final period in created.periods) period.canceled()],
    );
    final service = _FakeAmortizationPlanService();
    final detail = _amortizationDetail(
      plan: terminated,
      transactionId: 'termination-entry',
      occurredAt: DateTime(2026, 2, 1),
      amount: _money(25000),
    );
    final container = _amortizationContainer(
      plan: terminated,
      service: service,
      transactionId: 'termination-entry',
      transactionDetail: detail,
    );
    final provider = refundFormViewModelProvider(
      'termination-entry',
      editing: true,
      amortizationTermination: true,
    );

    final state = await container.read(provider.future);

    expect(state.status, RefundFormStatus.loaded);
    expect(state.amountText, '50');
    expect(state.availableCategoryAllocations.single.amount, _money(30000));
    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '100', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    final command = service.terminationEditCommands.single;
    expect(command.planId, created.id);
    expect(command.terminationId, 'termination');
    expect(command.categoryReturnAllocations.single.amount, _money(10000));
    expect(command.settlementAllocations.single.amount, _money(10000));
  });

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
  bool purchaseParent = false,
  _FakeAdvanceOrchestrationService? orchestration,
  _FakeConsumptionInstallmentService? consumptionRefunds,
  Future<List<InstallmentScheduleDTO>> Function(String contractId)?
  scheduleLoader,
  Future<List<ContractActivity>> Function(String contractId)? activityLoader,
}) {
  final cash = _account('cash');
  final bank = _account('bank');
  final receivable = _account('receivable');
  final credit = _account('credit', type: AccountType.liability);
  final expense = _account('expense', type: AccountType.expense);
  final accounts = {
    'cash': cash,
    'bank': bank,
    'receivable': receivable,
    'credit': credit,
    'expense': expense,
  };
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash, bank, credit])),
      accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
      accountLookupProvider.overrideWithValue(
        AsyncData(AccountLookup(accounts)),
      ),
      transactionDetailProvider(
        'refund',
      ).overrideWithValue(AsyncData(_refundDetail())),
      transactionDetailProvider('parent').overrideWithValue(
        AsyncData(
          purchaseParent
              ? _purchaseParentDetail()
              : _parentDetail(
                  closed: closed,
                  includeReceipt: includeReceipt,
                  combinedPayment: combinedPayment,
                ),
        ),
      ),
      if (purchaseParent)
        installmentQueryServiceProvider.overrideWithValue(
          _FakeInstallmentQueryService(),
        ),
      if (purchaseParent)
        consumptionInstallmentAppServiceProvider.overrideWithValue(
          consumptionRefunds ?? _FakeConsumptionInstallmentService(),
        ),
      if (scheduleLoader != null)
        installmentDetailProvider.overrideWith((ref, contractId) async {
          final schedules = await scheduleLoader(contractId);
          final installment = await _FakeInstallmentQueryService()
              .findInstallment(contractId);
          return installment == null
              ? null
              : InstallmentDetailDTO(
                  installment: installment,
                  schedules: schedules,
                );
        }),
      if (activityLoader != null)
        installmentActivitiesProvider.overrideWith(
          (ref, contractId) => activityLoader(contractId),
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

class _FakeConsumptionInstallmentService
    implements ConsumptionInstallmentAppService {
  _FakeConsumptionInstallmentService({this.limitForDate});

  final Money Function(DateTime)? limitForDate;
  final createCommands = <CreateConsumptionInstallmentRefundCommand>[];
  final editCommands = <EditConsumptionInstallmentRefundCommand>[];
  final deleteCommands = <DeleteConsumptionInstallmentRefundCommand>[];

  @override
  Future<Money> refundablePrincipal({
    required String contractId,
    required DateTime refundDate,
    String? excludedRefundTransactionId,
  }) async => limitForDate?.call(refundDate) ?? const Money(minorUnits: 10000);

  @override
  Future<ConsumptionInstallmentRefundResult> createRefund(
    CreateConsumptionInstallmentRefundCommand command,
  ) async {
    createCommands.add(command);
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: 'refund-new',
      principalReduction: Money.zero(),
    );
  }

  @override
  Future<ConsumptionInstallmentRefundResult> editRefund(
    EditConsumptionInstallmentRefundCommand command,
  ) async {
    editCommands.add(command);
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: command.transactionId,
      principalReduction: Money.zero(),
    );
  }

  @override
  Future<void> deleteRefund(
    DeleteConsumptionInstallmentRefundCommand command,
  ) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeInstallmentQueryService implements InstallmentQueryService {
  @override
  Future<InstallmentDTO?> findInstallment(String contractId) async {
    if (contractId != 'purchase-contract') return null;
    return InstallmentDTO(
      id: 'purchase-contract',
      name: '消费分期',
      liabilityAccountId: 'credit',
      installmentType: InstallmentType.purchase,
      principal: const Money(minorUnits: 10000),
      borrowingDate: DateTime(2026, 6, 1),
      status: InstallmentContractStatus.active,
      createdAt: DateTime(2026, 6, 1),
      repaymentProgress: const InstallmentRepaymentProgressDTO(
        paidPeriodCount: 0,
        totalPeriodCount: 12,
        remainingPrincipal: Money(minorUnits: 10000),
        repaid: RepaymentAmountBreakdown.zero,
      ),
      stageTerms: InstallmentContractTerms.singleStage(
        id: 'stage',
        totalPeriods: 12,
        firstDate: DateTime(2026, 7, 1),
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrual: InterestAccrualMethod.monthly,
        feeMinor: 0,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

TransactionReadModel _purchaseParentDetail() {
  const lines = [
    TransactionLine(
      id: 'purchase-category',
      transactionId: 'parent',
      lineNo: 1,
      role: TransactionRole.category,
      accountId: 'expense',
      amount: Money(minorUnits: 10000),
    ),
    TransactionLine(
      id: 'purchase-cash',
      transactionId: 'parent',
      lineNo: 2,
      role: TransactionRole.settlementOut,
      accountId: 'cash',
      amount: Money(minorUnits: 6000),
    ),
    TransactionLine(
      id: 'purchase-credit',
      transactionId: 'parent',
      lineNo: 3,
      role: TransactionRole.settlementOut,
      accountId: 'credit',
      amount: Money(minorUnits: 4000),
    ),
  ];
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'parent',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 6, 1),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: const TransactionOwnership(
        ownerType: installmentOwnerType,
        ownerId: 'purchase-contract',
      ),
    ),
    createdAt: DateTime(2026, 6, 1),
    lines: lines,
    refundSummary: const RefundSummary(
      refundedTotal: Money(minorUnits: 0),
      originalCategoryAllocations: [
        AccountAmountAllocation(
          accountId: 'expense',
          amount: Money(minorUnits: 10000),
        ),
      ],
      refundedCategoryAllocations: [],
    ),
  );
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

ProviderContainer _amortizationContainer({
  required AmortizationPlan plan,
  required AmortizationPlanAppService service,
  String transactionId = 'amortization-tx',
  TransactionReadModel? transactionDetail,
}) {
  final cash = _account('cash');
  final bank = _account('bank');
  final prepaid = _account('prepaid');
  final expense = _account('expense', type: AccountType.expense);
  final accounts = {
    'cash': cash,
    'bank': bank,
    'prepaid': prepaid,
    'expense': expense,
  };
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash, bank])),
      accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
      transactionDetailProvider(transactionId).overrideWithValue(
        AsyncData(
          transactionDetail ??
              _amortizationDetail(
                plan: plan,
                transactionId: transactionId,
                occurredAt: DateTime(2026, 1, 1),
                amount: plan.originalAmount,
              ),
        ),
      ),
      amortizationPlanProvider(
        plan.id,
      ).overrideWith((ref) => Stream.value(plan)),
      amortizationPlanAppServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionReadModel _amortizationDetail({
  required AmortizationPlan plan,
  required String transactionId,
  required DateTime occurredAt,
  required Money amount,
}) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: transactionId,
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: occurredAt,
      primaryAmount: amount,
      sourceKind: SourceKind.manual,
      ownership: TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: plan.id,
      ),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
    ),
    lines: [
      TransactionLine(
        id: '$transactionId-out',
        transactionId: transactionId,
        lineNo: 1,
        role: TransactionRole.settlementOut,
        accountId: 'prepaid',
        amount: amount,
      ),
      TransactionLine(
        id: '$transactionId-in',
        transactionId: transactionId,
        lineNo: 2,
        role: TransactionRole.settlementIn,
        accountId: 'cash',
        amount: amount,
      ),
    ],
  );
}

AmortizationPlan _amortizationPlan() {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: _money(30000),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'expense',
      amount: _money(30000),
    ),
    originalAmount: _money(30000),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: 3,
    initialTransactionId: 'amortization-tx',
  );
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
}

class _FakeAmortizationPlanService implements AmortizationPlanAppService {
  final refundCommands = <CreateAmortizationRefundCommand>[];
  final refundEditCommands = <EditAmortizationRefundCommand>[];
  final terminationCommands = <TerminateAmortizationPlanCommand>[];
  final terminationEditCommands = <EditAmortizationTerminationCommand>[];

  @override
  Future<AmortizationRefundResult> refund(
    CreateAmortizationRefundCommand command,
  ) async {
    refundCommands.add(command);
    return const AmortizationRefundResult(
      refundTransactionId: 'amortization-refund',
    );
  }

  @override
  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  ) async {
    terminationCommands.add(command);
    return const AmortizationTerminationResult(
      recognitionTransactionId: 'termination-entry',
      returnTransactionId: null,
    );
  }

  @override
  Future<AmortizationTerminationResult> editTermination(
    EditAmortizationTerminationCommand command,
  ) async {
    terminationEditCommands.add(command);
    return const AmortizationTerminationResult(
      recognitionTransactionId: 'termination-entry',
      returnTransactionId: 'termination-return',
    );
  }

  @override
  Future<void> editRefund(EditAmortizationRefundCommand command) async {
    refundEditCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

InstallmentScheduleDTO _schedule({required int principal}) {
  return InstallmentScheduleDTO(
    id: 'schedule-1',
    contractId: 'purchase-contract',
    periodNo: 1,
    expectedRepaymentDate: DateTime(2026, 7, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: InstallmentScheduleStatus.pending,
    createdAt: DateTime(2026, 6, 1),
  );
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
