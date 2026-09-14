import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

const engine = InstallmentPlanEngine();

void main() {
  InstallmentPlanTerms terms({
    int principal = 10000,
    int count = 4,
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.equalPrincipal,
  }) => InstallmentPlanTerms(
    principal: Money(minorUnits: principal),
    borrowingDate: DateTime(2026, 1, 8),
    stages: [
      AmortizingStage(
        dates: IntervalRepaymentDates(
          firstDate: DateTime(2026, 2, 8),
          count: count,
        ),
        method: method,
      ),
    ],
  );
  test('a future reduction leaves previous calculated periods unchanged', () {
    final input = terms();
    final base = engine.generate(input);
    final plan = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        principalReductions: [
          PrincipalReduction(
            date: DateTime(2026, 3, 20),
            principal: const Money(minorUnits: 2000),
          ),
        ],
      ),
    );
    expect(
      plan.entries.take(2).map((row) => row.expectedPrincipal),
      base.entries.take(2).map((row) => row.expectedPrincipal),
    );
    expect(plan.entries.map((row) => row.expectedPrincipal.minorUnits), [
      2500,
      2500,
      1500,
      1500,
    ]);
  });

  test('removing or changing operations regenerates from original terms', () {
    final input = terms();
    final first = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        principalReductions: [
          PrincipalReduction(
            date: DateTime(2026, 2, 8),
            principal: const Money(minorUnits: 3000),
          ),
        ],
      ),
    );
    final changed = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        principalReductions: [
          PrincipalReduction(
            date: DateTime(2026, 3, 8),
            principal: const Money(minorUnits: 2000),
          ),
        ],
      ),
    );
    final removed = engine.generate(input);
    expect(
      first.entries.fold<int>(
        0,
        (sum, row) => sum + row.expectedPrincipal.minorUnits,
      ),
      7000,
    );
    expect(changed.entries.map((row) => row.expectedPrincipal.minorUnits), [
      2500,
      1833,
      1833,
      1834,
    ]);
    expect(removed.entries.map((row) => row.expectedPrincipal.minorUnits), [
      2500,
      2500,
      2500,
      2500,
    ]);
  });

  test(
    'a fully prepaid plan has zero principal and rejects excess reductions at any position',
    () {
      final input = terms();
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(
              date: input.borrowingDate,
              principal: input.principal,
            ),
          ],
        ),
      );
      expect(
        plan.entries.every((row) => row.expectedPrincipal.minorUnits == 0),
        isTrue,
      );
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            principalReductions: [
              PrincipalReduction(
                date: DateTime(2026, 4, 1),
                principal: const Money(minorUnits: 6000),
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            principalReductions: [
              PrincipalReduction(
                date: DateTime(2026, 1, 1),
                principal: const Money(minorUnits: 1000),
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'deferment advances dates and consumes a reduction only once at the following stage',
    () {
      final input = InstallmentPlanTerms(
        principal: const Money(minorUnits: 100000),
        borrowingDate: DateTime(2026, 1, 8),
        stages: [
          DefermentStage(until: DateTime(2026, 4, 8)),
          AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime(2026, 5, 8),
              count: 2,
            ),
            method: InstallmentRepaymentMethod.equalPrincipal,
            rate: const InterestRate(
              ppm: 120000,
              period: InterestRatePeriod.annual,
            ),
          ),
        ],
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(
              date: DateTime(2026, 2, 8),
              principal: const Money(minorUnits: 40000),
            ),
          ],
        ),
      );
      expect(plan.entries, hasLength(2));
      expect(plan.entries.map((row) => row.expectedPrincipal.minorUnits), [
        30000,
        30000,
      ]);
      expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
        600,
        300,
      ]);
      expect(
        plan.entries.first.interestSegments.first.start,
        DateTime.utc(2026, 4, 9),
      );
    },
  );

  test(
    'all calculators conserve tiny principals without negative rounding tails',
    () {
      for (final method in [
        InstallmentRepaymentMethod.equalInstallment,
        InstallmentRepaymentMethod.equalPrincipal,
        InstallmentRepaymentMethod.interestFirst,
      ]) {
        for (final principal in [1, 5, 11, 101]) {
          final plan = engine.generate(
            terms(principal: principal, count: 7, method: method),
          );
          expect(
            plan.entries.fold<int>(
              0,
              (sum, row) => sum + row.expectedPrincipal.minorUnits,
            ),
            principal,
          );
          expect(
            plan.entries.every((row) => row.expectedPrincipal.minorUnits >= 0),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'annual accrual requires a full interest year even with monthly repayments',
    () {
      final input = InstallmentPlanTerms(
        principal: const Money(minorUnits: 100000),
        borrowingDate: DateTime(2026, 1, 8),
        stages: [
          AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime(2026, 2, 8),
              count: 12,
            ),
            method: InstallmentRepaymentMethod.interestFirst,
            accrual: InterestAccrualMethod.annual,
            rate: const InterestRate(
              ppm: 120000,
              period: InterestRatePeriod.annual,
            ),
          ),
        ],
      );
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            interestAdjustments: [
              InterestAdjustment(
                start: DateTime(2026, 1, 8),
                end: DateTime(2026, 2, 8),
                ratioPpm: 0,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          interestAdjustments: [
            InterestAdjustment(
              start: DateTime(2026, 1, 9),
              end: DateTime(2027, 1, 9),
              ratioPpm: 500000,
            ),
          ],
        ),
      );
      expect(
        plan.entries.map((row) => row.expectedInterest.minorUnits),
        everyElement(500),
      );
    },
  );

  group('interest units follow the configured first and final dates', () {
    final input = InstallmentPlanTerms(
      principal: const Money(minorUnits: 100000),
      borrowingDate: DateTime(2026, 1, 8),
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 2, 20),
            lastDate: DateTime(2028, 1, 9),
            count: 24,
          ),
          method: InstallmentRepaymentMethod.interestFirst,
          accrual: InterestAccrualMethod.annual,
          rate: const InterestRate(
            ppm: 120000,
            period: InterestRatePeriod.annual,
          ),
        ),
      ],
    );

    test(
      'rejects an anniversary that only covers part of the actual interest year',
      () {
        expect(
          () => engine.generate(
            input,
            operations: InstallmentPlanOperations(
              interestAdjustments: [
                InterestAdjustment(
                  start: DateTime(2026, 1, 8),
                  end: DateTime(2027, 1, 8),
                  ratioPpm: 0,
                ),
              ],
            ),
          ),
          throwsA(isA<BusinessException>()),
        );
      },
    );

    test(
      'adjacent annual adjustments include the irregular first and final periods',
      () {
        final base = engine.generate(input);
        final adjusted = engine.generate(
          input,
          operations: InstallmentPlanOperations(
            interestAdjustments: [
              InterestAdjustment(
                start: DateTime(2026, 1, 9),
                end: DateTime(2027, 1, 21),
                ratioPpm: 0,
              ),
              InterestAdjustment(
                start: DateTime(2027, 1, 21),
                end: DateTime(2028, 1, 10),
                ratioPpm: 500000,
              ),
            ],
          ),
        );
        expect(
          base.entries.map((row) => row.expectedInterest.minorUnits),
          everyElement(1000),
        );
        expect(
          adjusted.entries
              .take(12)
              .map((row) => row.expectedInterest.minorUnits),
          everyElement(0),
        );
        expect(
          adjusted.entries
              .skip(12)
              .map((row) => row.expectedInterest.minorUnits),
          everyElement(500),
        );
        expect(
          adjusted.entries.map((row) => row.expectedPrincipal),
          base.entries.map((row) => row.expectedPrincipal),
        );
      },
    );

    test(
      'a broad monthly adjustment still rejects partial coverage of the next unit',
      () {
        final monthly = InstallmentPlanTerms(
          principal: const Money(minorUnits: 100000),
          borrowingDate: DateTime(2026, 1, 8),
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 2, 20),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.interestFirst,
              rate: const InterestRate(
                ppm: 120000,
                period: InterestRatePeriod.annual,
              ),
            ),
          ],
        );
        expect(
          () => engine.generate(
            monthly,
            operations: InstallmentPlanOperations(
              interestAdjustments: [
                InterestAdjustment(
                  start: DateTime(2026, 1, 1),
                  end: DateTime(2026, 2, 26),
                  ratioPpm: 0,
                ),
              ],
            ),
          ),
          throwsA(isA<BusinessException>()),
        );
        final adjusted = engine.generate(
          monthly,
          operations: InstallmentPlanOperations(
            interestAdjustments: [
              InterestAdjustment(
                start: DateTime(2026, 1, 1),
                end: DateTime(2026, 2, 21),
                ratioPpm: 0,
              ),
            ],
          ),
        );
        expect(adjusted.entries.map((row) => row.expectedInterest.minorUnits), [
          0,
          1000,
        ]);
      },
    );
  });

  test('partial monthly units cannot be introduced by interest adjustment', () {
    final input = InstallmentPlanTerms(
      principal: const Money(minorUnits: 100000),
      borrowingDate: DateTime(2026, 1, 8),
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 4, 8),
            count: 1,
            intervalMonths: 3,
          ),
          method: InstallmentRepaymentMethod.interestFirst,
          rate: const InterestRate(
            ppm: 120000,
            period: InterestRatePeriod.annual,
          ),
        ),
      ],
    );
    final plan = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        interestAdjustments: [
          InterestAdjustment(
            start: DateTime(2026, 2, 9),
            end: DateTime(2026, 3, 9),
            ratioPpm: 0,
          ),
        ],
      ),
    );
    expect(plan.entries.single.expectedInterest.minorUnits, 2000);
  });

  test('adjustment sums exact interest before rounding the period', () {
    final input = InstallmentPlanTerms(
      principal: const Money(minorUnits: 100),
      borrowingDate: DateTime(2026, 1, 1),
      stages: [
        AmortizingStage(
          dates: ExplicitRepaymentDates([DateTime(2026, 1, 11)]),
          method: InstallmentRepaymentMethod.interestFirst,
          accrual: InterestAccrualMethod.daily,
          rate: const InterestRate(ppm: 6000, period: InterestRatePeriod.daily),
        ),
      ],
    );
    final plan = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        interestAdjustments: [
          InterestAdjustment(
            start: DateTime(2026, 1, 2),
            end: DateTime(2026, 1, 12),
            ratioPpm: 500000,
          ),
        ],
      ),
    );
    expect(plan.entries.single.expectedInterest.minorUnits, 3);
  });
}
