import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';

void main() {
  const query = LoanCalculatorQueryImpl();
  const onePercentMonthly = InterestRate(
    ppm: 10000,
    period: InterestRatePeriod.monthly,
  );

  InstallmentPlanTerms textbookTerms() {
    return InstallmentPlanTerms(
      principal: const Money(minorUnits: 1200000),
      borrowingDate: DateTime(2026, 1, 10),
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 2, 10),
            count: 12,
          ),
          method: InstallmentRepaymentMethod.equalInstallment,
          rate: onePercentMonthly,
        ),
      ],
    );
  }

  test('calculate returns periods, stage summary, totals and metrics', () {
    final calculation = query.calculate(textbookTerms());

    expect(calculation.periods, hasLength(12));
    expect(calculation.periods.first.principal, const Money(minorUnits: 94619));
    expect(calculation.periods.first.interest, const Money(minorUnits: 12000));
    expect(
      calculation.periods.first.remainingPrincipal,
      const Money(minorUnits: 1105381),
    );
    expect(calculation.periods.last.remainingPrincipal, Money.zero());
    expect(calculation.totalPrincipal, const Money(minorUnits: 1200000));
    expect(calculation.totalInterest, const Money(minorUnits: 79423));
    expect(calculation.totalFee, Money.zero());
    expect(calculation.totalRepayment, const Money(minorUnits: 1279423));
    final stage = calculation.stages.single;
    expect(stage.index, 0);
    expect(stage.firstPeriodNo, 1);
    expect(stage.lastPeriodNo, 12);
    expect(stage.installmentAmount, const Money(minorUnits: 106619));
    expect(stage.lastPeriodDifference, const Money(minorUnits: -5));
    expect(calculation.metrics.isAvailable, isTrue);
    expect(calculation.metrics.monthlyIrr, closeTo(0.01, 0.0015));
  });

  test('stage index points at the position within all stages', () {
    final calculation = query.calculate(
      InstallmentPlanTerms(
        principal: const Money(minorUnits: 10000),
        borrowingDate: DateTime(2026, 1, 1),
        stages: [
          DefermentStage(until: DateTime(2026, 6, 1)),
          AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime(2026, 7, 1),
              count: 2,
            ),
            method: InstallmentRepaymentMethod.equalPrincipal,
          ),
        ],
      ),
    );

    expect(calculation.stages.single.index, 1);
    expect(calculation.periods.map((p) => p.periodNo), [1, 2]);
  });

  test(
    'prepayment simulation freezes paid periods and recalculates the tail',
    () {
      final base = query.calculate(textbookTerms());
      final simulation = query.simulatePrepayment(
        LoanPrepaymentSimulationRequest(
          terms: textbookTerms(),
          paidPeriods: 4,
          prepaymentDate: DateTime(2026, 6, 15),
          prepaymentPrincipal: const Money(minorUnits: 500000),
        ),
      );

      expect(simulation.periods, hasLength(12));
      expect(simulation.firstRecalculatedPeriodNo, 6);
      for (var i = 0; i < 5; i++) {
        expect(simulation.periods[i].principal, base.periods[i].principal);
        expect(simulation.periods[i].interest, base.periods[i].interest);
      }
      final principalSum = simulation.periods.fold<int>(
        0,
        (sum, period) => sum + period.principal.minorUnits,
      );
      expect(principalSum + 500000, 1200000);
      expect(simulation.totalInterest.minorUnits, lessThan(79423));
      expect(
        simulation.interestSaved,
        const Money(minorUnits: 79423) - simulation.totalInterest,
      );
      expect(
        simulation.periods[5].remainingPrincipal.minorUnits,
        lessThan(base.periods[5].remainingPrincipal.minorUnits),
      );
      expect(simulation.periods.last.remainingPrincipal, Money.zero());
    },
  );

  test('prepayment simulation preserves quarterly and annual rhythms', () {
    for (final months in [3, 12]) {
      final simulation = query.simulatePrepayment(
        LoanPrepaymentSimulationRequest(
          terms: InstallmentPlanTerms(
            principal: const Money(minorUnits: 1200000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [
              AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime(2026, 1 + months, 1),
                  count: 4,
                  intervalMonths: months,
                ),
                method: InstallmentRepaymentMethod.equalPrincipal,
                rate: onePercentMonthly,
                accrual: months == 12
                    ? InterestAccrualMethod.annual
                    : InterestAccrualMethod.monthly,
              ),
            ],
          ),
          paidPeriods: 1,
          prepaymentDate: DateTime(2026, 1 + months, 2),
          prepaymentPrincipal: const Money(minorUnits: 300000),
        ),
      );

      expect(simulation.firstRecalculatedPeriodNo, 2);
      expect(simulation.periods[1].interest.minorUnits, 6000 * months);
      expect(simulation.periods[1].date, DateTime(2026, 1 + 2 * months, 1));
      expect(simulation.periods.last.remainingPrincipal, Money.zero());
    }
  });

  for (final prepaymentMinor in [10000, 50000]) {
    test(
      'balloon simulation matches contract after prepaying $prepaymentMinor',
      () {
        const principal = Money(minorUnits: 100000);
        final borrowingDate = DateTime(2026, 1, 1);
        final terms = InstallmentContractTerms(
          stages: [
            InstallmentContractStage(
              id: 'balloon',
              terms: AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime(2026, 2, 1),
                  count: 4,
                ),
                method: InstallmentRepaymentMethod.equalPrincipal,
                rate: onePercentMonthly,
                endPrincipal: const Money(minorUnits: 60000),
              ),
            ),
          ],
        );
        var nextId = 0;
        final loan = const InstallmentOriginationService()
            .originateDisbursement(
              contractId: 'loan',
              liabilityAccountId: 'liability',
              terms: InstallmentOriginationTerms(
                principal: principal,
                borrowingDate: borrowingDate,
                stageTerms: terms,
              ),
              createdAt: borrowingDate,
              newScheduleId: () => 'schedule-${nextId++}',
            );
        final date = DateTime(2026, 1, 15);
        final simulation = query.simulatePrepayment(
          LoanPrepaymentSimulationRequest(
            terms: terms.planTerms(principal, borrowingDate),
            paidPeriods: 0,
            prepaymentDate: date,
            prepaymentPrincipal: Money(minorUnits: prepaymentMinor),
          ),
        );
        final actual = const InstallmentPlanEngine()
            .recalculate(
              InstallmentPlanContext.fromContract(
                contract: loan.contract,
                schedules: loan.schedules,
                prepaymentPrincipal: Money(minorUnits: prepaymentMinor),
              ),
              RecalculateAfterPrepayment(date),
            )
            .recalculatedRows;

        expect(
          simulation.periods.map((r) => r.principal),
          actual.map((r) => r.principal),
        );
        expect(
          simulation.periods.map((r) => r.interest),
          actual.map((r) => r.interest),
        );
        expect(
          simulation.periods.map((r) => r.date),
          actual.map((r) => r.date),
        );
        expect(simulation.periods.last.remainingPrincipal, Money.zero());
        expect(
          simulation.totalInterest.minorUnits,
          prepaymentMinor == 10000 ? 3150 : 2000,
        );
        expect(
          simulation.interestSaved.minorUnits,
          prepaymentMinor == 10000 ? 250 : 1400,
        );
      },
    );
  }

  test('prepayment simulation supports deferment and rejects bad inputs', () {
    final multiStage = InstallmentPlanTerms(
      principal: const Money(minorUnits: 10000),
      borrowingDate: DateTime(2026, 1, 1),
      stages: [
        DefermentStage(until: DateTime(2026, 6, 1)),
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 7, 1),
            count: 2,
          ),
          method: InstallmentRepaymentMethod.equalPrincipal,
        ),
      ],
    );

    final deferred = query.simulatePrepayment(
      LoanPrepaymentSimulationRequest(
        terms: multiStage,
        paidPeriods: 0,
        prepaymentDate: DateTime(2026, 6, 15),
        prepaymentPrincipal: const Money(minorUnits: 1000),
      ),
    );
    expect(deferred.periods.map((p) => p.principal.minorUnits), [4500, 4500]);
    expect(deferred.periods.last.remainingPrincipal, Money.zero());
    expect(
      () => query.simulatePrepayment(
        LoanPrepaymentSimulationRequest(
          terms: textbookTerms(),
          paidPeriods: 12,
          prepaymentDate: DateTime(2026, 6, 15),
          prepaymentPrincipal: const Money(minorUnits: 1000),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => query.simulatePrepayment(
        LoanPrepaymentSimulationRequest(
          terms: textbookTerms(),
          paidPeriods: 2,
          prepaymentDate: DateTime(2026, 6, 15),
          prepaymentPrincipal: Money.zero(),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  for (final paid in [1, 2]) {
    test(
      'prepayment after period $paid retains stage rules, fees and frozen rows',
      () {
        final terms = InstallmentPlanTerms(
          principal: const Money(minorUnits: 120000),
          borrowingDate: DateTime(2026, 1, 1),
          stages: [
            DefermentStage(until: DateTime(2026, 2, 1)),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 3, 1),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.interestFirst,
              rate: onePercentMonthly,
              fee: const Money(minorUnits: 2000),
            ),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 5, 1),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              rate: onePercentMonthly,
              fee: const Money(minorUnits: 4000),
            ),
          ],
        );
        final result = query.simulatePrepayment(
          LoanPrepaymentSimulationRequest(
            terms: terms,
            paidPeriods: paid,
            prepaymentDate: DateTime(2026, paid + 2, 2),
            prepaymentPrincipal: const Money(minorUnits: 30000),
          ),
        );
        expect(result.firstRecalculatedPeriodNo, paid + 1);
        expect(result.periods.map((p) => p.principal.minorUnits), [
          0,
          0,
          45000,
          45000,
        ]);
        expect(result.periods.map((p) => p.interest.minorUnits), [
          1200,
          paid == 1 ? 900 : 1200,
          900,
          450,
        ]);
        expect(result.periods.map((p) => p.fee.minorUnits), [
          1000,
          1000,
          2000,
          2000,
        ]);
        expect(result.interestSaved.minorUnits, paid == 1 ? 750 : 450);
        expect(result.totalFee.minorUnits, 6000);
        expect(result.stages.map((s) => s.index), [1, 2]);
        expect(result.periods.last.remainingPrincipal, Money.zero());
        expect(result.periods.map((p) => p.date), [
          for (var month = 3; month <= 6; month++) DateTime(2026, month, 1),
        ]);
      },
    );
  }
}
