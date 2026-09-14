import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';

void main() {
  const query = LoanCalculatorQueryImpl();
  final terms = InstallmentPlanTerms(
    principal: const Money(minorUnits: 1000000),
    borrowingDate: DateTime(2026, 1, 1),
    stages: [
      AmortizingStage(
        dates: IntervalRepaymentDates(
          firstDate: DateTime(2026, 2, 1),
          count: 3,
        ),
        method: InstallmentRepaymentMethod.interestFirst,
        rate: const InterestRate(ppm: 36000, period: InterestRatePeriod.annual),
        accrual: InterestAccrualMethod.daily,
        fee: const Money(minorUnits: 900),
      ),
    ],
    dayCount: DayCountConvention.thirty360,
  );

  LoanChangeSimulation simulate(InstallmentPlanOperations operations) =>
      query.simulateChanges(
        LoanChangeSimulationRequest(terms: terms, operations: operations),
      );

  test(
    'combines repeated operations chronologically and includes prepaid principal in totals',
    () {
      final reductions = [
        PrincipalReduction(
          date: DateTime(2026, 2, 15),
          principal: const Money(minorUnits: 200000),
        ),
        PrincipalReduction(
          date: DateTime(2026, 3, 15),
          principal: const Money(minorUnits: 100000),
        ),
      ];
      final changes = [
        _rateChange(DateTime(2026, 2, 20), 72000),
        _rateChange(DateTime(2026, 3, 20), 18000),
      ];
      final adjustments = [
        InterestAdjustment(
          start: DateTime(2026, 2, 1),
          end: DateTime(2026, 3, 1),
          ratioPpm: 500000,
        ),
        InterestAdjustment(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 4, 1),
          ratioPpm: 1200000,
        ),
      ];
      for (final reversed in [false, true]) {
        final result = simulate(
          InstallmentPlanOperations(
            principalReductions: reversed
                ? reductions.reversed.toList()
                : reductions,
            rateChangesByStage: {
              0: reversed ? changes.reversed.toList() : changes,
            },
            interestAdjustments: reversed
                ? adjustments.reversed.toList()
                : adjustments,
          ),
        );
        expect(result.original.totalInterest.minorUnits, 9000);
        expect(result.periods.map((p) => p.interest.minorUnits), [
          3100,
          1520,
          3570,
        ]);
        expect(result.periods.map((p) => p.principal.minorUnits), [
          0,
          0,
          700000,
        ]);
        expect(result.periods.map((p) => p.remainingPrincipal.minorUnits), [
          1000000,
          800000,
          0,
        ]);
        expect(result.totalInterest.minorUnits, 8190);
        expect(result.interestChange.minorUnits, -810);
        expect(result.chargesChange.minorUnits, -810);
        expect(result.totalFee.minorUnits, 900);
        expect(result.prepaymentPrincipal.minorUnits, 300000);
        expect(result.totalRepayment.minorUnits, 1009090);
        expect(
          result.periods.fold(Money.zero(), (sum, p) => sum + p.total) +
              result.prepaymentPrincipal,
          result.totalRepayment,
        );
      }
    },
  );

  test('no operations reproduce the original loan', () {
    final result = simulate(const InstallmentPlanOperations());
    expect(result.totalRepayment, result.original.totalRepayment);
    expect(result.chargesChange, Money.zero());
    expect(result.prepaymentPrincipal, Money.zero());
  });

  test(
    'same-day prepayments are counted once in balances and affect the following interest period',
    () {
      final result = simulate(
        InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(
              date: DateTime(2026, 3, 1, 18),
              principal: const Money(minorUnits: 100000),
            ),
            PrincipalReduction(
              date: DateTime(2026, 2, 1, 9),
              principal: const Money(minorUnits: 200000),
            ),
          ],
        ),
      );
      expect(result.periods.map((p) => p.interest.minorUnits), [
        3100,
        2240,
        2170,
      ]);
      expect(result.periods.map((p) => p.remainingPrincipal.minorUnits), [
        800000,
        700000,
        0,
      ]);
    },
  );

  test('higher rates produce a positive cost change', () {
    final result = simulate(
      InstallmentPlanOperations(
        rateChangesByStage: {
          0: [_rateChange(DateTime(2026, 1, 2), 72000)],
        },
      ),
    );
    expect(result.totalInterest.minorUnits, 18000);
    expect(result.interestChange.minorUnits, 9000);
    expect(result.chargesChange.minorUnits, 9000);
  });

  test('rejects conflicting or inapplicable operations', () {
    for (final operations in [
      InstallmentPlanOperations(
        rateChangesByStage: {
          0: [
            _rateChange(DateTime(2026, 2, 20), 72000),
            _rateChange(DateTime(2026, 2, 20), 18000),
          ],
        },
      ),
      InstallmentPlanOperations(
        rateChangesByStage: {
          1: [_rateChange(DateTime(2026, 2, 20), 72000)],
        },
      ),
      InstallmentPlanOperations(
        rateChangesByStage: {
          0: [_rateChange(DateTime(2026, 5, 1), 72000)],
        },
      ),
      InstallmentPlanOperations(
        interestAdjustments: [
          InterestAdjustment(
            start: DateTime(2026, 2, 1),
            end: DateTime(2026, 3, 1),
            ratioPpm: 500000,
          ),
          InterestAdjustment(
            start: DateTime(2026, 2, 15),
            end: DateTime(2026, 4, 1),
            ratioPpm: 0,
          ),
        ],
      ),
      InstallmentPlanOperations(
        principalReductions: [
          PrincipalReduction(
            date: DateTime(2026, 2, 15),
            principal: const Money(minorUnits: 1100000),
          ),
        ],
      ),
    ]) {
      expect(() => simulate(operations), throwsA(isA<BusinessException>()));
    }
  });

  test(
    'a saved result retains its operation snapshot after the caller edits inputs',
    () {
      final reductions = [
        PrincipalReduction(
          date: DateTime(2026, 2, 15),
          principal: const Money(minorUnits: 200000),
        ),
      ];
      final result = simulate(
        InstallmentPlanOperations(principalReductions: reductions),
      );
      reductions.clear();
      expect(result.prepaymentPrincipal.minorUnits, 200000);
      expect(
        () => result.operations.principalReductions.clear(),
        throwsUnsupportedError,
      );
    },
  );
}

RateChange _rateChange(DateTime effectiveDate, int ratePpm) => RateChange(
  resetDate: effectiveDate,
  effectiveDate: effectiveDate,
  referenceRate: ReferenceRate(
    type: InterestRateType.lprFiveYearPlus,
    date: effectiveDate.subtract(const Duration(days: 1)),
    ratePpm: ratePpm,
    source: 'test',
  ),
  spreadBp: 0,
);
