import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

void main() {
  const engine = InstallmentPlanEngine();
  const onePercentMonthly = InterestRate(
    ppm: 10000,
    period: InterestRatePeriod.monthly,
  );

  group('golden', () {
    test(
      '12000 over 12 months at 1% per month is the 1066.19 textbook plan',
      () {
        final plan = engine.plan(
          InstallmentPlanTerms(
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
          ),
        );

        final stage = plan.stages.single;
        expect(stage.installmentAmount, const Money(minorUnits: 106619));
        expect(stage.lastPeriodDifference, const Money(minorUnits: -5));
        expect(plan.entries.map((e) => e.expectedInterest.minorUnits), [
          12000,
          11054,
          10098,
          9133,
          8158,
          7173,
          6179,
          5175,
          4160,
          3136,
          2101,
          1056,
        ]);
        expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
          94619,
          95565,
          96521,
          97486,
          98461,
          99446,
          100440,
          101444,
          102459,
          103483,
          104518,
          105558,
        ]);
        expect(
          plan.entries.fold<int>(
            0,
            (sum, e) => sum + e.expectedInterest.minorUnits,
          ),
          79423,
        );
      },
    );

    test('equal principal at 4.9% annual accrues on the declining balance', () {
      final entries = engine.generate(
        principal: const Money(minorUnits: 10000000),
        borrowingDate: DateTime(2026, 1, 15),
        firstRepaymentDate: DateTime(2026, 2, 15),
        lastRepaymentDate: DateTime(2026, 11, 15),
        totalPeriods: 10,
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.annual,
        ratePpm: 49000,
      );

      expect(entries.map((e) => e.expectedPrincipal.minorUnits).toSet(), {
        1000000,
      });
      expect(entries.map((e) => e.expectedInterest.minorUnits), [
        40833,
        36750,
        32667,
        28583,
        24500,
        20417,
        16333,
        12250,
        8167,
        4083,
      ]);
    });

    test('flat fee preset splits fee across periods without interest', () {
      final entries = engine.generate(
        principal: const Money(minorUnits: 120000),
        borrowingDate: DateTime(2026, 5, 9),
        firstRepaymentDate: DateTime(2026, 6, 9),
        lastRepaymentDate: DateTime(2027, 5, 9),
        totalPeriods: 12,
        method: InstallmentRepaymentMethod.flatFee,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.annual,
        ratePpm: 72000,
        totalFeeMinor: 10560,
      );

      expect(entries.map((e) => e.expectedPrincipal.minorUnits).toSet(), {
        10000,
      });
      expect(entries.map((e) => e.expectedFee.minorUnits).toSet(), {880});
      expect(entries.map((e) => e.expectedInterest.minorUnits).toSet(), {0});
    });
  });

  group('stages', () {
    test('deferment, interest-only years and equal principal years chain', () {
      const rate = InterestRate(ppm: 31000, period: InterestRatePeriod.annual);
      final plan = engine.plan(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 1200000),
          borrowingDate: DateTime(2026, 9, 1),
          stages: [
            DefermentStage(until: DateTime(2030, 7, 1)),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2031, 7, 1),
                count: 2,
                intervalMonths: 12,
              ),
              method: InstallmentRepaymentMethod.interestFirst,
              rate: rate,
              accrual: InterestAccrualMethod.annual,
            ),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2033, 7, 1),
                count: 3,
                intervalMonths: 12,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              rate: rate,
              accrual: InterestAccrualMethod.annual,
            ),
          ],
        ),
      );

      expect(plan.entries.map((e) => e.periodNo), [1, 2, 3, 4, 5]);
      expect(plan.entries.first.expectedRepaymentDate, DateTime(2031, 7, 1));
      expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
        0,
        0,
        400000,
        400000,
        400000,
      ]);
      expect(plan.entries.map((e) => e.expectedInterest.minorUnits), [
        37200,
        37200,
        37200,
        24800,
        12400,
      ]);
      expect(plan.stages.map((s) => (s.firstPeriodNo, s.lastPeriodNo)), [
        (1, 2),
        (3, 5),
      ]);
    });

    test('explicit end principal feeds the next stage', () {
      final plan = engine.plan(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 10000),
          borrowingDate: DateTime(2026, 1, 1),
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 2, 1),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              endPrincipal: const Money(minorUnits: 6000),
            ),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 4, 1),
                count: 3,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
            ),
          ],
        ),
      );

      expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
        2000,
        2000,
        2000,
        2000,
        2000,
      ]);
    });

    test(
      'non-final equal principal stage requires an explicit end principal',
      () {
        expect(
          () => engine.plan(
            InstallmentPlanTerms(
              principal: const Money(minorUnits: 10000),
              borrowingDate: DateTime(2026, 1, 1),
              stages: [
                AmortizingStage(
                  dates: IntervalRepaymentDates(
                    firstDate: DateTime(2026, 2, 1),
                    count: 2,
                  ),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                ),
                AmortizingStage(
                  dates: IntervalRepaymentDates(
                    firstDate: DateTime(2026, 4, 1),
                    count: 1,
                  ),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                ),
              ],
            ),
          ),
          throwsA(_invalidCommand(contains('end principal'))),
        );
      },
    );

    test('balloon end principal is repaid on top of the final period', () {
      final plan = engine.plan(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 1000000),
          borrowingDate: DateTime(2026, 1, 1),
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 2, 1),
                count: 2,
              ),
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: onePercentMonthly,
              endPrincipal: const Money(minorUnits: 500000),
            ),
          ],
        ),
      );

      final stage = plan.stages.single;
      expect(stage.installmentAmount, const Money(minorUnits: 258756));
      expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
        248756,
        751244,
      ]);
      expect(plan.entries.map((e) => e.expectedInterest.minorUnits), [
        10000,
        7512,
      ]);
      expect(stage.lastPeriodDifference, const Money(minorUnits: 500000));
    });

    test('stage dates must follow the previous stage', () {
      expect(
        () => engine.plan(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [
              DefermentStage(until: DateTime(2026, 6, 1)),
              AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime(2026, 3, 1),
                  count: 2,
                ),
                method: InstallmentRepaymentMethod.equalPrincipal,
              ),
            ],
          ),
        ),
        throwsA(_invalidCommand(contains('strictly increasing'))),
      );
    });

    test('explicit accrual start cannot bypass the stage timeline', () {
      expect(
        () => engine.plan(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [
              DefermentStage(until: DateTime(2026, 6, 1)),
              AmortizingStage(
                accrualStartDate: DateTime(2026, 1, 1),
                dates: ExplicitRepaymentDates([DateTime(2026, 3, 1)]),
                method: InstallmentRepaymentMethod.equalPrincipal,
              ),
            ],
          ),
        ),
        throwsA(_invalidCommand(contains('strictly increasing'))),
      );
    });

    test('a trailing deferment cannot leave principal unallocated', () {
      expect(
        () => engine.plan(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [
              AmortizingStage(
                dates: ExplicitRepaymentDates([DateTime(2026, 2, 1)]),
                method: InstallmentRepaymentMethod.interestFirst,
              ),
              DefermentStage(until: DateTime(2026, 6, 1)),
            ],
          ),
        ),
        throwsA(_invalidCommand(contains('principal'))),
      );
    });

    test('explicit dates require a positive repayment rhythm', () {
      expect(
        () => engine.plan(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [
              AmortizingStage(
                dates: ExplicitRepaymentDates([
                  DateTime(2026, 2, 1),
                ], intervalMonths: 0),
                method: InstallmentRepaymentMethod.equalPrincipal,
                rate: onePercentMonthly,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('deferment alone produces no periods', () {
      expect(
        () => engine.plan(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000),
            borrowingDate: DateTime(2026, 1, 1),
            stages: [DefermentStage(until: DateTime(2026, 6, 1))],
          ),
        ),
        throwsA(_invalidCommand(contains('amortizing stage'))),
      );
    });
  });

  group('conventions', () {
    test('quarterly rhythm with monthly accrual counts three months', () {
      final plan = engine.plan(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 1200000),
          borrowingDate: DateTime(2026, 1, 1),
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 4, 1),
                count: 4,
                intervalMonths: 3,
              ),
              method: InstallmentRepaymentMethod.interestFirst,
              rate: onePercentMonthly,
            ),
          ],
        ),
      );

      expect(plan.entries.map((e) => e.expectedRepaymentDate), [
        DateTime(2026, 4, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 10, 1),
        DateTime(2027, 1, 1),
      ]);
      expect(plan.entries.map((e) => e.expectedInterest.minorUnits).toSet(), {
        36000,
      });
    });

    test('daily accrual converts annual rates by the day count convention', () {
      const rate = InterestRate(ppm: 73000, period: InterestRatePeriod.annual);
      List<int> interest(DayCountConvention dayCount) {
        return engine
            .plan(
              InstallmentPlanTerms(
                principal: const Money(minorUnits: 1000000),
                borrowingDate: DateTime(2026, 1, 1),
                dayCount: dayCount,
                stages: [
                  AmortizingStage(
                    dates: ExplicitRepaymentDates([DateTime(2026, 1, 31)]),
                    method: InstallmentRepaymentMethod.interestFirst,
                    rate: rate,
                    accrual: InterestAccrualMethod.daily,
                  ),
                ],
              ),
            )
            .entries
            .map((e) => e.expectedInterest.minorUnits)
            .toList();
      }

      expect(interest(DayCountConvention.thirty365), [6000]);
      expect(interest(DayCountConvention.thirty360), [6083]);
    });

    test('rounding mode applies to every amount that lands on cents', () {
      List<int> principals(RoundingMode rounding) {
        return engine
            .plan(
              InstallmentPlanTerms(
                principal: const Money(minorUnits: 1001),
                borrowingDate: DateTime(2026, 1, 1),
                rounding: rounding,
                stages: [
                  AmortizingStage(
                    dates: IntervalRepaymentDates(
                      firstDate: DateTime(2026, 2, 1),
                      count: 2,
                    ),
                    method: InstallmentRepaymentMethod.equalPrincipal,
                  ),
                ],
              ),
            )
            .entries
            .map((e) => e.expectedPrincipal.minorUnits)
            .toList();
      }

      expect(principals(RoundingMode.halfUp), [501, 500]);
      expect(principals(RoundingMode.halfEven), [500, 501]);
      expect(principals(RoundingMode.down), [500, 501]);
      expect(principals(RoundingMode.up), [501, 500]);
    });
  });

  group('equal installment amount', () {
    InstallmentPlan planWith(EqualInstallmentAmount amount) {
      return engine.plan(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 10000),
          borrowingDate: DateTime(2026, 1, 1),
          stages: [
            AmortizingStage(
              dates: ExplicitRepaymentDates([
                DateTime(2026, 2, 15),
                DateTime(2026, 3, 17),
                DateTime(2026, 4, 16),
              ]),
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: onePercentMonthly,
              accrual: InterestAccrualMethod.daily,
              installmentAmount: amount,
            ),
          ],
        ),
      );
    }

    test('actual rate discounting keeps the existing behaviour', () {
      final plan = planWith(const EqualInstallmentAmount.actualRate());
      expect(
        plan.stages.single.installmentAmount,
        const Money(minorUnits: 3417),
      );
      expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
        3267,
        3350,
        3383,
      ]);
    });

    test('nominal rate drifts when the first period is long', () {
      final plan = planWith(const EqualInstallmentAmount.nominalRate());
      expect(
        plan.stages.single.installmentAmount,
        const Money(minorUnits: 3400),
      );
      expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
        3250,
        3332,
        3418,
      ]);
      expect(
        plan.stages.single.lastPeriodDifference,
        const Money(minorUnits: 52),
      );
    });

    test(
      'fixed amount must cover interest and last until the final period',
      () {
        expect(
          () => planWith(
            const EqualInstallmentAmount.fixed(Money(minorUnits: 50)),
          ),
          throwsA(_invalidCommand(contains('cover the interest'))),
        );
        expect(
          () => planWith(
            const EqualInstallmentAmount.fixed(Money(minorUnits: 20000)),
          ),
          throwsA(_invalidCommand(contains('before the final period'))),
        );
        final plan = planWith(
          const EqualInstallmentAmount.fixed(Money(minorUnits: 3500)),
        );
        expect(
          plan.stages.single.installmentAmount,
          const Money(minorUnits: 3500),
        );
        expect(plan.entries.map((e) => e.expectedPrincipal.minorUnits), [
          3350,
          3433,
          3217,
        ]);
      },
    );
  });

  test('a 360 period plan is computed quickly with exact arithmetic', () {
    final stopwatch = Stopwatch()..start();
    final plan = engine.plan(
      InstallmentPlanTerms(
        principal: const Money(minorUnits: 100000000),
        borrowingDate: DateTime(2026, 1, 1),
        stages: [
          AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime(2026, 2, 1),
              count: 360,
            ),
            method: InstallmentRepaymentMethod.equalInstallment,
            rate: const InterestRate(
              ppm: 42000,
              period: InterestRatePeriod.annual,
            ),
          ),
        ],
      ),
    );
    stopwatch.stop();

    expect(plan.entries, hasLength(360));
    expect(
      plan.entries.fold<int>(
        0,
        (sum, e) => sum + e.expectedPrincipal.minorUnits,
      ),
      100000000,
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}

Matcher _invalidCommand(Matcher message) {
  return isA<BusinessException>()
      .having((error) => error.code, 'code', 'credit.contract.invalid_command')
      .having((error) => error.message, 'message', message);
}
