import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_case_query_service.dart';
import 'package:smartflow/application/orchestration/amortization/query/amortization_plan_query_service.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

class _MockTransactionQueryService extends Mock
    implements TransactionQueryService {}

class _MockAdvanceCaseQueryService extends Mock
    implements AdvanceCaseQueryService {}

class _MockInstallmentQueryService extends Mock
    implements InstallmentQueryService {}

class _MockAmortizationPlanQueryService extends Mock
    implements AmortizationPlanQueryService {}

class _MockRepaymentRepository extends Mock implements RepaymentRepository {}

class _MockInstallmentContract extends Mock
    implements InstallmentContractReadModel {}

class _MockInstallmentSchedule extends Mock
    implements InstallmentScheduleReadModel {}

class _MockRepayment extends Mock implements Repayment {}

void main() {
  late _MockTransactionQueryService transactions;
  late _MockAdvanceCaseQueryService advances;
  late _MockInstallmentQueryService installments;
  late _MockAmortizationPlanQueryService amortizations;
  late _MockRepaymentRepository repayments;
  late TransactionDetailContextQuery query;

  setUp(() {
    transactions = _MockTransactionQueryService();
    advances = _MockAdvanceCaseQueryService();
    installments = _MockInstallmentQueryService();
    amortizations = _MockAmortizationPlanQueryService();
    repayments = _MockRepaymentRepository();
    query = TransactionDetailContextQueryImpl(
      transactions: transactions,
      advances: advances,
      installments: installments,
      amortizations: amortizations,
      repaymentRepository: repayments,
    );
  });

  test(
    'amortization entries keep the plan initial transaction as anchor',
    () async {
      final plan = AmortizationPlan.create(
        id: 'plan-1',
        kind: AmortizationKind.prepaidExpense,
        deferralAccountId: 'prepaid',
        fundingAllocations: const [
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 12000),
          ),
        ],
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'insurance',
            amount: Money(minorUnits: 12000),
          ),
        ],
        originalAmount: const Money(minorUnits: 12000),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        firstRecognitionAt: DateTime(2026, 2),
        recognitionCount: 3,
        initialTransactionId: 'anchor',
      );
      final anchor = _transaction(
        id: 'anchor',
        purpose: BusinessPurpose.dailyExpense,
        ownerType: orchestrationAmortizationOwnerType,
      );
      final recognition = _transaction(
        id: 'recognition',
        purpose: BusinessPurpose.dailyExpense,
        ownerType: orchestrationAmortizationOwnerType,
      );
      when(
        () => transactions.findTransactionDetail('recognition'),
      ).thenAnswer((_) async => recognition);
      when(
        () => transactions.findTransactionDetail('anchor'),
      ).thenAnswer((_) async => anchor);
      when(
        () => amortizations.findById('plan-1'),
      ).thenAnswer((_) async => plan);

      final context = await query.findById('recognition');

      expect(context, isNotNull);
      expect(context!.transaction.id, 'recognition');
      expect(context.anchorTransaction.id, 'anchor');
      expect(context.anchorGroup.anchor.id, 'anchor');
      expect(context.owner, isA<AmortizationTransactionDetailOwnerContext>());
      expect(
        (context.owner as AmortizationTransactionDetailOwnerContext)
            .initialTransactionId,
        'anchor',
      );
    },
  );

  test('missing owner facts are represented as an unknown owner', () async {
    final transaction = _transaction(
      id: 'tx-1',
      purpose: BusinessPurpose.dailyExpense,
      ownerType: 'unknown.owner',
    );
    when(
      () => transactions.findTransactionDetail('tx-1'),
    ).thenAnswer((_) async => transaction);

    final context = await query.findById('tx-1');

    expect(context, isNotNull);
    expect(context!.owner, isA<UnknownTransactionDetailOwnerContext>());
  });

  test('loads advance summary and orchestration scenario', () async {
    final anchor =
        _transaction(
          id: 'advance',
          purpose: BusinessPurpose.advance,
          ownerType: orchestrationAdvanceOwnerType,
          ownerId: 'case-1',
        ).copyWith(
          advanceSummary: const AdvanceSummary(
            advanceAmount: Money(minorUnits: 10000),
            receivedAmount: Money(minorUnits: 4000),
            outstanding: Money(minorUnits: 6000),
            isClosed: false,
          ),
        );
    when(
      () => transactions.findTransactionDetail('advance'),
    ).thenAnswer((_) async => anchor);
    when(() => advances.findById('case-1')).thenAnswer(
      (_) async => const AdvanceCase(
        id: 'case-1',
        scenario: AdvanceScenario.aa,
        trackingMode: AdvanceTrackingMode.itemized,
        aaPeopleCount: 3,
      ),
    );

    final context = await query.findById('advance');

    final owner = context!.owner as AdvanceTransactionDetailOwnerContext;
    expect(owner.scenario, AdvanceScenario.aa);
    expect(owner.outstanding, const Money(minorUnits: 6000));
    expect(owner.aaPeopleCount, 3);
  });

  test('loads installment progress and remaining principal', () async {
    final transaction = _transaction(
      id: 'purchase',
      purpose: BusinessPurpose.dailyExpense,
      ownerType: installmentOwnerType,
      ownerId: 'contract-1',
    );
    final contract = _MockInstallmentContract();
    final paid = _MockInstallmentSchedule();
    final pending = _MockInstallmentSchedule();
    when(
      () => transactions.findTransactionDetail('purchase'),
    ).thenAnswer((_) async => transaction);
    when(
      () => installments.findContract('contract-1'),
    ).thenAnswer((_) async => contract);
    when(
      () => installments.listSchedules('contract-1'),
    ).thenAnswer((_) async => [paid, pending]);
    when(() => contract.installmentType).thenReturn(InstallmentType.purchase);
    when(() => contract.status).thenReturn(InstallmentContractStatus.active);
    when(() => contract.principal).thenReturn(const Money(minorUnits: 10000));
    when(() => paid.status).thenReturn(InstallmentScheduleStatus.paid);
    when(() => pending.status).thenReturn(InstallmentScheduleStatus.pending);
    when(
      () => pending.expectedPrincipal,
    ).thenReturn(const Money(minorUnits: 6000));

    final context = await query.findById('purchase');

    final owner = context!.owner as InstallmentTransactionDetailOwnerContext;
    expect(owner.paidPeriodCount, 1);
    expect(owner.totalPeriodCount, 2);
    expect(owner.remainingPrincipal, const Money(minorUnits: 6000));
  });

  test('loads credit repayment type and stable target identity', () async {
    final transaction = _transaction(
      id: 'repayment-tx',
      purpose: BusinessPurpose.debtRepayment,
      ownerType: creditRepaymentOwnerType,
      ownerId: 'repayment-1',
    );
    final repayment = _MockRepayment();
    when(
      () => transactions.findTransactionDetail('repayment-tx'),
    ).thenAnswer((_) async => transaction);
    when(
      () => repayments.findRepayment('repayment-1'),
    ).thenAnswer((_) async => repayment);
    when(() => repayment.repaymentType).thenReturn(RepaymentType.bill);
    when(() => repayment.targetType).thenReturn(RepaymentTargetType.bill);
    when(() => repayment.targetId).thenReturn('bill-1');

    final context = await query.findById('repayment-tx');

    final owner = context!.owner as RepaymentTransactionDetailOwnerContext;
    expect(owner.repaymentType, RepaymentType.bill);
    expect(owner.targetType, RepaymentTargetType.bill);
    expect(owner.targetId, 'bill-1');
  });
}

TransactionReadModel _transaction({
  required String id,
  required BusinessPurpose purpose,
  String? ownerType,
  String ownerId = 'plan-1',
}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1),
    primaryAmount: const Money(minorUnits: 12000),
    ownership: ownerType == null
        ? null
        : TransactionOwnership(ownerType: ownerType, ownerId: ownerId),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
