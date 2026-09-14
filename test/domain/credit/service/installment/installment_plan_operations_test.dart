import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

const engine = InstallmentPlanEngine();
Money money(int minor) => Money(minorUnits: minor);
DateTime date(int month, int day) => DateTime(2026, month, day);

AmortizingStage stage({
  int month = 9,
  int count = 1,
  int interval = 1,
  int? end,
  int ratePpm = 36000,
  InstallmentRepaymentMethod method = InstallmentRepaymentMethod.interestFirst,
  InterestAccrualMethod accrual = InterestAccrualMethod.daily,
}) => AmortizingStage(
  dates: IntervalRepaymentDates(
    firstDate: date(month, 8),
    count: count,
    intervalMonths: interval,
  ),
  method: method,
  accrual: accrual,
  rate: InterestRate(ppm: ratePpm, period: InterestRatePeriod.annual),
  endPrincipal: end == null ? null : money(end),
);

RateChange rateChange(int month, int day, int ppm) => RateChange(
  resetDate: date(month, day),
  effectiveDate: date(month, day),
  referenceRate: ReferenceRate(
    type: InterestRateType.lprOneYear,
    date: date(month, day - 1),
    ratePpm: ppm,
    source: 'test',
  ),
  spreadBp: 0,
);

InstallmentPlanTerms terms(AmortizingStage value) => InstallmentPlanTerms(
  principal: money(10000000),
  borrowingDate: date(8, 8),
  stages: [value],
);

void main() {
  group('annual interest-first repayment boundaries', () {
    final input = InstallmentPlanTerms(
      principal: money(10000000),
      borrowingDate: DateTime.utc(2025, 6, 22),
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime.utc(2025, 12, 20),
            count: 3,
            intervalMonths: 12,
            lastDate: DateTime.utc(2027, 6, 22),
          ),
          method: InstallmentRepaymentMethod.interestFirst,
          accrual: InterestAccrualMethod.daily,
          rate: const InterestRate(
            ppm: 36000,
            period: InterestRatePeriod.annual,
          ),
        ),
      ],
    );
    final changes = [
      for (final (year, ppm) in [(2025, 18000), (2026, 9000)])
        RateChange(
          resetDate: DateTime.utc(year, 12, 21),
          effectiveDate: DateTime.utc(year, 12, 21),
          referenceRate: ReferenceRate(
            type: InterestRateType.lprOneYear,
            date: DateTime.utc(year, 12, 20),
            ratePpm: ppm,
            source: 'test',
          ),
          spreadBp: 0,
        ),
    ];
    final reduction = PrincipalReduction(
      date: DateTime.utc(2025, 12, 20),
      principal: money(2000000),
    );
    final exemption = InterestAdjustment(
      start: DateTime.utc(2025, 12, 20),
      end: DateTime.utc(2026, 12, 20),
      ratioPpm: 0,
    );

    InstallmentPlan calculate({
      List<PrincipalReduction> reductions = const [],
      List<InterestAdjustment> adjustments = const [],
    }) => engine.generate(
      input,
      operations: InstallmentPlanOperations(
        principalReductions: reductions,
        rateChangesByStage: {0: changes},
        interestAdjustments: adjustments,
      ),
    );

    test('December 21 repricing covers each complete following period', () {
      final plan = calculate();
      expect(plan.entries.map((row) => row.expectedRepaymentDate), [
        DateTime(2025, 12, 20),
        DateTime(2026, 12, 20),
        DateTime.utc(2027, 6, 22),
      ]);
      // 181, 365 and 184 days at 10, 5 and 2.5 yuan per day (360-day year).
      expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
        181000,
        182500,
        46000,
      ]);
      final segments = plan.entries.map((row) => row.interestSegments.single);
      expect(segments.map((segment) => segment.start), [
        DateTime.utc(2025, 6, 23),
        DateTime.utc(2025, 12, 21),
        DateTime.utc(2026, 12, 21),
      ]);
      expect(segments.map((segment) => segment.end), [
        DateTime.utc(2025, 12, 21),
        DateTime.utc(2026, 12, 21),
        DateTime.utc(2027, 6, 23),
      ]);
      expect(segments.map((segment) => segment.rate?.ppm), [
        36000,
        18000,
        9000,
      ]);
    });

    test(
      'repayment-day prepayment reduces only subsequent opening balances',
      () {
        final plan = calculate(reductions: [reduction]);
        expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
          181000,
          146000,
          36800,
        ]);
        expect(
          plan.entries.map(
            (row) => row.interestSegments.single.principal.minorUnits,
          ),
          [10000000, 8000000, 8000000],
        );
        expect(plan.entries.map((row) => row.expectedPrincipal.minorUnits), [
          0,
          0,
          8000000,
        ]);
      },
    );

    test(
      'repayment-date exemption removes exactly the second period interest',
      () {
        final plan = calculate(adjustments: [exemption]);
        expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
          181000,
          0,
          46000,
        ]);
        expect(plan.entries.map((row) => row.expectedPrincipal.minorUnits), [
          0,
          0,
          10000000,
        ]);
      },
    );

    for (final (startDay, expectedInterest) in [
      (19, [180000, 182500, 46000]),
      (20, [181000, 182000, 46000]),
    ]) {
      test(
        'one-day exemption after December $startDay includes its end date',
        () {
          final plan = calculate(
            adjustments: [
              InterestAdjustment(
                start: DateTime.utc(2025, 12, startDay),
                end: DateTime.utc(2025, 12, startDay + 1),
                ratioPpm: 0,
              ),
            ],
          );
          expect(
            plan.entries.map((row) => row.expectedInterest.minorUnits),
            expectedInterest,
          );
        },
      );
    }

    test('prepayment on or after the final repayment has no future period', () {
      for (final day in [22, 23]) {
        expect(
          () => calculate(
            reductions: [
              PrincipalReduction(
                date: DateTime.utc(2027, 6, day),
                principal: money(2000000),
              ),
            ],
          ),
          throwsA(isA<BusinessException>()),
        );
      }
    });

    test(
      'prepayment, exemption and annual repricing share the same boundaries',
      () {
        final plan = calculate(
          reductions: [reduction],
          adjustments: [exemption],
        );
        expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
          181000,
          0,
          36800,
        ]);
        expect(plan.entries.last.expectedPrincipal.minorUnits, 8000000);
      },
    );
  });

  test('repricing stays in its stage and preserves the next initial rate', () {
    final input = InstallmentPlanTerms(
      principal: money(10000000),
      borrowingDate: date(8, 8),
      stages: [stage(), stage(month: 10, ratePpm: 72000)],
    );
    final plan = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        rateChangesByStage: {
          0: [rateChange(8, 20, 18000)],
        },
      ),
    );
    // First stage: 11 days at 3.6% + 20 days at 1.8%. Second: 30 days at 7.2%.
    expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
      21000,
      60000,
    ]);
    final scoped = engine.generate(
      input,
      operations: InstallmentPlanOperations(
        rateChangesByStage: {
          0: [rateChange(8, 20, 18000)],
          1: [rateChange(8, 20, 24000)],
        },
      ),
    );
    expect(scoped.entries.map((row) => row.expectedInterest.minorUnits), [
      21000,
      20000,
    ]);
    expect(
      () => engine.generate(
        input,
        operations: InstallmentPlanOperations(
          rateChangesByStage: {
            0: [rateChange(8, 20, 18000), rateChange(8, 20, 24000)],
          },
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => engine.generate(
        input,
        operations: InstallmentPlanOperations(
          rateChangesByStage: {
            2: [rateChange(8, 20, 18000)],
          },
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  test('a boundary repricing applies only to the next stage it belongs to', () {
    final plan = engine.generate(
      InstallmentPlanTerms(
        principal: money(10000000),
        borrowingDate: date(8, 8),
        stages: [stage(), stage(month: 10)],
      ),
      operations: InstallmentPlanOperations(
        rateChangesByStage: {
          1: [rateChange(9, 8, 18000)],
        },
      ),
    );
    expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
      31000,
      15000,
    ]);
  });

  test(
    'interest adjustment updates the final installment difference after rounding',
    () {
      final plan = engine.generate(
        InstallmentPlanTerms(
          principal: money(1200000),
          borrowingDate: date(1, 10),
          stages: [
            AmortizingStage(
              method: InstallmentRepaymentMethod.equalInstallment,
              rate: const InterestRate(
                ppm: 10000,
                period: InterestRatePeriod.monthly,
              ),
              dates: IntervalRepaymentDates(firstDate: date(2, 10), count: 12),
            ),
          ],
        ),
        operations: InstallmentPlanOperations(
          interestAdjustments: [
            InterestAdjustment(
              start: date(12, 10),
              end: DateTime(2027, 1, 10),
              ratioPpm: 0,
            ),
          ],
        ),
      );
      expect(plan.entries.last.expectedPrincipal.minorUnits, 105558);
      expect(plan.entries.last.expectedInterest.minorUnits, 0);
      expect(plan.stages.single.installmentAmount?.minorUnits, 106619);
      expect(plan.stages.single.lastPeriodDifference?.minorUnits, -1061);
    },
  );

  test(
    'mixed monthly and daily accrual validates each affected unit independently',
    () {
      final input = InstallmentPlanTerms(
        principal: money(10000000),
        borrowingDate: date(8, 8),
        stages: [
          stage(accrual: InterestAccrualMethod.monthly),
          stage(month: 10),
        ],
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          interestAdjustments: [
            InterestAdjustment(
              start: date(8, 8),
              end: date(9, 25),
              ratioPpm: 500000,
            ),
          ],
        ),
      );
      expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
        15000,
        // September 9-25: 17 days at half interest, then 13 days at full interest.
        21500,
      ]);
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            interestAdjustments: [
              InterestAdjustment(
                start: date(8, 20),
                end: date(9, 25),
                ratioPpm: 500000,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'deferment carries reductions and repricings into the next amortizing stage',
    () {
      final plan = engine.generate(
        InstallmentPlanTerms(
          principal: money(10000000),
          borrowingDate: date(7, 8),
          stages: [
            DefermentStage(until: date(8, 8)),
            stage(accrual: InterestAccrualMethod.monthly),
          ],
        ),
        operations: InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(date: date(7, 20), principal: money(1000000)),
          ],
          rateChangesByStage: {
            1: [rateChange(7, 25, 18000)],
          },
        ),
      );
      expect(plan.entries, hasLength(1));
      expect(plan.entries.single.expectedPrincipal.minorUnits, 9000000);
      expect(plan.entries.single.expectedInterest.minorUnits, 13500);
      expect(plan.stages.single.openingPrincipal?.minorUnits, 9000000);
    },
  );

  test('rate facts reject impossible dates and negative reference rates', () {
    for (final change in [
      RateChange(
        resetDate: date(8, 21),
        effectiveDate: date(8, 20),
        referenceRate: rateChange(8, 20, 18000).referenceRate,
        spreadBp: 0,
      ),
      RateChange(
        resetDate: date(8, 19),
        effectiveDate: date(8, 20),
        referenceRate: rateChange(8, 21, 18000).referenceRate,
        spreadBp: 0,
      ),
      rateChange(8, 20, -1),
    ]) {
      expect(
        () => engine.generate(
          terms(stage()),
          operations: InstallmentPlanOperations(
            rateChangesByStage: {
              0: [change],
            },
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    }
  });

  test(
    'daily segments produce 175.00 after adjustment without changing principal',
    () {
      final input = terms(stage());
      final changes = [rateChange(8, 20, 18000)];
      final base = engine.generate(
        input,
        operations: InstallmentPlanOperations(rateChangesByStage: {0: changes}),
      );
      final adjusted = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          rateChangesByStage: {0: changes},
          interestAdjustments: [
            InterestAdjustment(
              start: date(8, 15),
              end: date(8, 25),
              ratioPpm: 500000,
            ),
          ],
        ),
      );
      expect(base.entries.single.expectedInterest.minorUnits, 21000);
      // (8/15, 8/25] covers 4 days at 10 yuan and 6 days at 5 yuan.
      expect(adjusted.entries.single.expectedInterest.minorUnits, 17500);
      expect(
        adjusted.entries.single.expectedPrincipal,
        base.entries.single.expectedPrincipal,
      );
      expect(adjusted.entries.single.interestSegments, hasLength(2));
    },
  );

  test(
    'repayment-day principal reduction starts with the following period',
    () {
      final input = terms(stage(count: 2));
      final within = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(date: date(8, 20), principal: money(1000000)),
          ],
          rateChangesByStage: {
            0: [rateChange(8, 15, 18000)],
          },
        ),
      );
      expect(
        within.entries.first.interestSegments.every(
          (segment) => segment.principal == money(9000000),
        ),
        isTrue,
      );
      expect(within.stages.single.openingPrincipal?.minorUnits, 9000000);
      expect(
        within.entries.first.interestSegments.map(
          (segment) => segment.start.day,
        ),
        [9, 15],
      );
      for (final (day, firstInterest) in [(7, 27900), (8, 31000), (9, 31000)]) {
        final boundary = engine.generate(
          input,
          operations: InstallmentPlanOperations(
            principalReductions: [
              PrincipalReduction(date: date(9, day), principal: money(1000000)),
            ],
          ),
        );
        expect(
          boundary.entries.first.expectedInterest.minorUnits,
          firstInterest,
        );
        expect(boundary.entries.last.expectedInterest.minorUnits, 27000);
      }
    },
  );

  for (final deduction in [5000000, 8000000]) {
    test(
      'two stages cap contractual balances after a $deduction reduction exactly once',
      () {
        final first = stage(
          month: 2,
          count: 5,
          end: 5000000,
          method: InstallmentRepaymentMethod.equalPrincipal,
        );
        final second = stage(
          month: 7,
          count: 2,
          end: 2000000,
          method: InstallmentRepaymentMethod.equalPrincipal,
        );
        final plan = engine.generate(
          InstallmentPlanTerms(
            principal: money(10000000),
            borrowingDate: date(1, 8),
            stages: [first, second],
          ),
          operations: InstallmentPlanOperations(
            principalReductions: [
              PrincipalReduction(
                date: date(2, 20),
                principal: money(deduction),
              ),
            ],
          ),
        );
        expect(plan.entries.first.expectedPrincipal.minorUnits, 1000000);
        expect(
          plan.entries
              .skip(1)
              .take(4)
              .every((entry) => entry.expectedPrincipal.minorUnits == 0),
          isTrue,
        );
        expect(
          plan.stages.last.openingPrincipal?.minorUnits,
          deduction == 5000000 ? 4000000 : 1000000,
        );
        expect(
          plan.stages.last.closingPrincipal?.minorUnits,
          deduction == 5000000 ? 2000000 : 1000000,
        );
        expect(
          plan.entries.fold<int>(
            deduction,
            (sum, entry) => sum + entry.expectedPrincipal.minorUnits,
          ),
          10000000,
        );
        expect(first.endPrincipal?.minorUnits, 5000000);
        expect(second.endPrincipal?.minorUnits, 2000000);
      },
    );
  }

  test(
    'monthly partial adjustment is rejected unless repricing has switched the period to days',
    () {
      final input = terms(stage(accrual: InterestAccrualMethod.monthly));
      final adjustment = InterestAdjustment(
        start: date(8, 20),
        end: date(9, 1),
        ratioPpm: 0,
      );
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            interestAdjustments: [adjustment],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          interestAdjustments: [adjustment],
          rateChangesByStage: {
            0: [rateChange(8, 15, 18000)],
          },
        ),
      );
      expect(
        plan.entries.single.interestSegments.every(
          (segment) => segment.accrual == InterestAccrualMethod.daily,
        ),
        isTrue,
      );
      expect(plan.entries.single.expectedInterest.minorUnits, 12500);
    },
  );

  test(
    'complete units and adjacent intervals support exemption and increased interest',
    () {
      final input = terms(
        stage(accrual: InterestAccrualMethod.monthly, count: 2),
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          interestAdjustments: [
            InterestAdjustment(start: date(8, 8), end: date(9, 8), ratioPpm: 0),
            InterestAdjustment(
              start: date(9, 8),
              end: date(10, 8),
              ratioPpm: 1200000,
            ),
          ],
        ),
      );
      expect(plan.entries.map((entry) => entry.expectedInterest.minorUnits), [
        0,
        36000,
      ]);
      expect(
        () => engine.generate(
          input,
          operations: InstallmentPlanOperations(
            interestAdjustments: [
              InterestAdjustment(
                start: date(8, 8),
                end: date(10, 8),
                ratioPpm: 500000,
              ),
              InterestAdjustment(
                start: date(9, 8),
                end: date(10, 8),
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
    'interleaved operations preserve stage fees and settle the final balance once',
    () {
      final input = InstallmentPlanTerms(
        principal: money(120000),
        borrowingDate: date(1, 8),
        stages: [
          for (final (month, count, end) in [(2, 2, 80000), (4, 3, 30000)])
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: date(month, 8),
                count: count,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              accrual: InterestAccrualMethod.monthly,
              rate: const InterestRate(
                ppm: 36000,
                period: InterestRatePeriod.annual,
              ),
              endPrincipal: money(end),
              fee: money(101),
            ),
        ],
      );
      final plan = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: [
            PrincipalReduction(date: date(4, 20), principal: money(10000)),
            PrincipalReduction(date: date(2, 20), principal: money(10000)),
          ],
          rateChangesByStage: {
            0: [rateChange(2, 15, 72000)],
            1: [rateChange(4, 15, 18000)],
          },
          interestAdjustments: [
            InterestAdjustment(
              start: date(4, 15),
              end: date(6, 9),
              ratioPpm: 500000,
            ),
          ],
        ),
      );

      expect(plan.entries.map((row) => row.expectedPrincipal.minorUnits), [
        20000,
        10000,
        16667,
        11667,
        41666,
      ]);
      expect(plan.entries.map((row) => row.expectedInterest.minorUnits), [
        360,
        450,
        // Stage two starts at its own 3.6%: 80000 * 3.6% / 12.
        240,
        // 53333 * (3.6% * 6 / 360 + 1.8% * (1 + 23 * 50%) / 360).
        65,
        31,
      ]);
      expect(plan.entries.map((row) => row.expectedFee.minorUnits), [
        51,
        50,
        34,
        34,
        33,
      ]);
      expect(plan.stages.last.openingPrincipal, money(80000));
      expect(plan.stages.last.closingPrincipal, money(30000));
      expect(
        plan.entries[3].interestSegments.map(
          (segment) => segment.principal.minorUnits,
        ),
        [53333, 53333],
      );
    },
  );

  test('multiple custom stages are valid and mixed contracts are rejected', () {
    final first = stage(method: InstallmentRepaymentMethod.custom);
    final second = stage(month: 10, method: InstallmentRepaymentMethod.custom);
    expect(
      engine
          .generate(
            InstallmentPlanTerms(
              principal: money(100),
              borrowingDate: date(8, 8),
              stages: [first, second],
            ),
          )
          .entries,
      hasLength(2),
    );
    expect(
      () => engine.generate(
        InstallmentPlanTerms(
          principal: money(100),
          borrowingDate: date(8, 8),
          stages: [first, stage(month: 10)],
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  test(
    'operation ordering does not affect alternating repricings and reductions',
    () {
      final input = terms(
        stage(count: 6, method: InstallmentRepaymentMethod.equalInstallment),
      );
      final reductions = [
        PrincipalReduction(date: date(9, 20), principal: money(300000)),
        PrincipalReduction(date: date(11, 25), principal: money(400000)),
      ];
      final changes = [rateChange(9, 15, 18000), rateChange(11, 18, 24000)];
      final a = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: reductions,
          rateChangesByStage: {0: changes},
        ),
      );
      final b = engine.generate(
        input,
        operations: InstallmentPlanOperations(
          principalReductions: reductions.reversed.toList(),
          rateChangesByStage: {0: changes.reversed.toList()},
        ),
      );
      expect(
        a.entries.map((entry) => entry.expectedPrincipal),
        b.entries.map((entry) => entry.expectedPrincipal),
      );
      expect(
        a.entries.map((entry) => entry.expectedInterest),
        b.entries.map((entry) => entry.expectedInterest),
      );
      expect(
        a.entries.fold<int>(
          700000,
          (sum, entry) => sum + entry.expectedPrincipal.minorUnits,
        ),
        input.principal.minorUnits,
      );
    },
  );
}
