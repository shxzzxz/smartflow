import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/domain/credit/entity/installment_repricing.dart';

void main() {
  const recalculator = InstallmentPlanEngine();
  test(
    'repricing principal follows its stage after frozen and deferment stages are trimmed',
    () {
      final effective = DateTime.utc(2026, 1, 1);
      final change = RateChange(
        resetDate: effective,
        effectiveDate: effective,
        referenceRate: ReferenceRate(
          type: ReferenceRateType.lprOneYear,
          date: effective,
          ratePpm: 36000,
          source: 'test',
        ),
        spreadBp: 0,
      );
      final terms = InstallmentContractTerms(
        stages: [
          InstallmentContractStage(
            id: 'first',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2025, 10, 1),
                count: 1,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              endPrincipal: const Money(minorUnits: 8000000),
            ),
          ),
          InstallmentContractStage(
            id: 'defer',
            terms: DefermentStage(until: DateTime(2025, 12, 20)),
          ),
          InstallmentContractStage(
            id: 'floating',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 1, 20),
                count: 3,
              ),
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: const InterestRate(
                ppm: 48000,
                period: InterestRatePeriod.annual,
              ),
              floatingRate: FloatingRateRule(
                referenceRateType: ReferenceRateType.lprOneYear,
                spreadBp: 0,
                firstResetDate: effective,
                firstEffectiveDate: effective,
              ),
            ),
          ),
        ],
      );
      var id = 0;
      final loan = const InstallmentOriginationService().originateDisbursement(
        contractId: 'loan',
        liabilityAccountId: 'account',
        createdAt: DateTime(2025, 9, 1),
        newScheduleId: () => 'period-${++id}',
        terms: InstallmentOriginationTerms(
          principal: const Money(minorUnits: 10000000),
          borrowingDate: DateTime(2025, 9, 1),
          stageTerms: terms,
        ),
      );
      loan.schedules.first.markPaid();
      loan.schedules[1].reviseExpectation(
        expectedPrincipal: const Money(minorUnits: 2000000),
      );
      final updates = recalculator
          .recalculate(
            InstallmentPlanContext.fromContract(
              contract: loan.contract,
              schedules: loan.schedules,
              prepaymentPrincipal: Money(minorUnits: 0),
            ),
            ApplyInstallmentRepricing(
              InstallmentRepricing(
                id: 'reset',
                contractId: 'loan',
                stageId: 'floating',
                change: change,
              ),
            ),
          )
          .recalculatedRows;
      expect(updates.map((r) => r.periodNo), [2, 3, 4]);
      expect(
        updates.map((r) => (r.principal.minorUnits, r.interest.minorUnits)),
        [(2000000, 28000), (2995507, 18000), (3004493, 9013)],
      );
      expect(loan.schedules.first.expectedPrincipal.minorUnits, 2000000);
      expect(loan.schedules.first.status, InstallmentScheduleStatus.paid);
    },
  );
  test(
    'caps stage two balance, keeps interest and fees, and passes balance to stage three',
    () {
      final aggregate = _loan();
      final original = aggregate.schedules;
      original[0].markPaid();
      final result = recalculator
          .recalculate(
            InstallmentPlanContext.fromContract(
              contract: aggregate.contract,
              schedules: original,
              prepaymentPrincipal: Money(minorUnits: 5000000),
            ),
            RecalculateAfterPrepayment(DateTime(2026, 2, 15)),
          )
          .recalculatedRows;
      expect(result.map((r) => r.id), [
        original[1].id,
        original[2].id,
        original[3].id,
      ]);
      expect(result.first.principal.minorUnits, 0);
      expect(result.first.interest.minorUnits, 40000);
      expect(result.first.fee.minorUnits, 1000);
      expect(result.skip(1).map((r) => r.principal.minorUnits), [
        2000000,
        2000000,
      ]);
      expect(result.skip(1).map((r) => r.interest.minorUnits), [80000, 40000]);
      expect(original.first.expectedPrincipal.minorUnits, 1000000);
      expect(
        (aggregate.contract.stageTerms.stages[1].terms as AmortizingStage)
            .endPrincipal!
            .minorUnits,
        5000000,
      );
      for (var i = 0; i < result.length; i++) {
        expect(result[i].date, original[i + 1].expectedRepaymentDate);
      }
      final restored = recalculator
          .recalculate(
            InstallmentPlanContext.fromContract(
              contract: aggregate.contract,
              schedules: original,
              prepaymentPrincipal: Money(minorUnits: 0),
            ),
            RecalculateAfterPrepayment(DateTime(2026, 2, 15)),
          )
          .recalculatedRows;
      expect(restored.first.principal.minorUnits, 4000000);
      expect(restored.skip(1).map((r) => r.principal.minorUnits), [
        2500000,
        2500000,
      ]);
    },
  );

  test(
    'zero principal stage ignores a fixed amount that would repay principal',
    () {
      final aggregate = _loan(fixed: true);
      aggregate.schedules[0].markPaid();
      final result = recalculator
          .recalculate(
            InstallmentPlanContext.fromContract(
              contract: aggregate.contract,
              schedules: aggregate.schedules,
              prepaymentPrincipal: Money(minorUnits: 5000000),
            ),
            RecalculateAfterPrepayment(DateTime(2026, 2, 15)),
          )
          .recalculatedRows;
      expect(result.first.principal.minorUnits, 0);
      expect(result.first.interest.minorUnits, greaterThan(0));
    },
  );

  test('prepayment during deferment preserves interest-free timeline', () {
    final aggregate = _loan();
    final result = recalculator
        .recalculate(
          InstallmentPlanContext.fromContract(
            contract: aggregate.contract,
            schedules: aggregate.schedules,
            prepaymentPrincipal: Money(minorUnits: 1000000),
          ),
          RecalculateAfterPrepayment(DateTime(2025, 12, 15)),
        )
        .recalculatedRows;
    expect(result.length, 4);
    expect(result.first.date, DateTime(2026, 2, 1));
    expect(result.fold<int>(0, (n, r) => n + r.principal.minorUnits), 9000000);
  });

  test('a later non-pending stage advances the anchor', () {
    final aggregate = _loan();
    aggregate.schedules[2].skip();
    final result = recalculator
        .recalculate(
          InstallmentPlanContext.fromContract(
            contract: aggregate.contract,
            schedules: aggregate.schedules,
            prepaymentPrincipal: Money(minorUnits: 1000000),
          ),
          RecalculateAfterPrepayment(DateTime(2026, 2, 15)),
        )
        .recalculatedRows;
    expect(result.single.id, aggregate.schedules.last.id);
    expect(result.single.principal.minorUnits, 1500000);
  });

  test('final balloon repays capped balance in final period', () {
    final aggregate = _loan(balloon: true);
    aggregate.schedules[2].markPaid();
    final frozenPrincipal = aggregate.schedules
        .take(3)
        .fold<int>(0, (n, s) => n + s.expectedPrincipal.minorUnits);
    final result = recalculator
        .recalculate(
          InstallmentPlanContext.fromContract(
            contract: aggregate.contract,
            schedules: aggregate.schedules,
            prepaymentPrincipal: Money(
              minorUnits: 10000000 - frozenPrincipal - 1000000,
            ),
          ),
          RecalculateAfterPrepayment(aggregate.contract.borrowingDate),
        )
        .recalculatedRows;
    expect(result.single.principal.minorUnits, 1000000);
  });
}

InstallmentOriginationResult _loan({bool fixed = false, bool balloon = false}) {
  final terms = InstallmentContractTerms(
    stages: [
      InstallmentContractStage(
        id: 'defer',
        terms: DefermentStage(until: DateTime(2026, 1, 1)),
      ),
      InstallmentContractStage(
        id: 'second',
        terms: AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 2, 1),
            count: 2,
          ),
          method: fixed
              ? InstallmentRepaymentMethod.equalInstallment
              : InstallmentRepaymentMethod.custom,
          rate: const InterestRate(
            ppm: 10000,
            period: InterestRatePeriod.monthly,
          ),
          endPrincipal: const Money(minorUnits: 5000000),
          fee: const Money(minorUnits: 2000),
          installmentAmount: fixed
              ? const EqualInstallmentAmount.fixed(Money(minorUnits: 1100000))
              : const EqualInstallmentAmount.nominalRate(),
        ),
      ),
      InstallmentContractStage(
        id: 'third',
        terms: AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 4, 1),
            count: 2,
          ),
          method: InstallmentRepaymentMethod.equalPrincipal,
          endPrincipal: balloon ? const Money(minorUnits: 2000000) : null,
          rate: const InterestRate(
            ppm: 20000,
            period: InterestRatePeriod.monthly,
          ),
        ),
      ),
    ],
  );
  var id = 0;
  final result = const InstallmentOriginationService().originateDisbursement(
    contractId: 'loan',
    liabilityAccountId: 'account',
    createdAt: DateTime(2025, 9, 1),
    newScheduleId: () => 'schedule-${id++}',
    terms: InstallmentOriginationTerms(
      principal: const Money(minorUnits: 10000000),
      borrowingDate: DateTime(2025, 9, 1),
      stageTerms: terms,
    ),
  );
  if (!fixed) {
    // 已有计划允许人工修正；重算必须按冻结事实扣本金。
    result.schedules[0].reviseExpectation(
      expectedPrincipal: const Money(minorUnits: 1000000),
    );
    result.schedules[1].reviseExpectation(
      expectedPrincipal: const Money(minorUnits: 4000000),
    );
    result.contract.reviseStageTerms(
      InstallmentContractTerms(
        stages: [
          terms.stages[0],
          InstallmentContractStage(
            id: 'second',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 2, 1),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              rate: const InterestRate(
                ppm: 10000,
                period: InterestRatePeriod.monthly,
              ),
              endPrincipal: const Money(minorUnits: 5000000),
              fee: const Money(minorUnits: 2000),
            ),
          ),
          terms.stages[2],
        ],
      ),
    );
  }
  return result;
}
