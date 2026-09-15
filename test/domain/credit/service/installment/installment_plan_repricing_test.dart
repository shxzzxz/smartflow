import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';

void main() {
  const engine = InstallmentPlanEngine();
  final start = DateTime.utc(2025, 12, 20);
  final effective = DateTime.utc(2026, 1, 1);
  for (final dates in [
    (DateTime.utc(2025, 8, 30), DateTime.utc(2025, 9, 1)),
    (DateTime.utc(2025, 8, 20), DateTime.utc(2025, 8, 25)),
  ]) {
    test(
      'stage opening uses the latest effective rate through ${dates.$2}',
      () {
        RateChange repricing(DateTime reset, DateTime effective, int ppm) =>
            RateChange(
              resetDate: reset,
              effectiveDate: effective,
              referenceRate: ReferenceRate(
                type: InterestRateType.lprOneYear,
                date: reset.subtract(const Duration(days: 1)),
                ratePpm: ppm,
                source: 'test',
              ),
              spreadBp: 0,
            );
        final result = engine.generate(
          InstallmentPlanTerms(
            principal: const Money(minorUnits: 10000000),
            borrowingDate: DateTime.utc(2024, 9, 1),
            stages: [
              DefermentStage(until: DateTime.utc(2025, 8, 31)),
              AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime.utc(2025, 12, 20),
                  count: 5,
                  intervalMonths: 12,
                ),
                method: InstallmentRepaymentMethod.interestFirst,
                rate: const InterestRate(
                  ppm: 48000,
                  period: InterestRatePeriod.annual,
                ),
                accrual: InterestAccrualMethod.daily,
              ),
              AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime.utc(2030, 12, 20),
                  count: 1,
                ),
                method: InstallmentRepaymentMethod.equalPrincipal,
                rate: const InterestRate(
                  ppm: 50000,
                  period: InterestRatePeriod.annual,
                ),
                accrual: InterestAccrualMethod.daily,
              ),
            ],
          ),
          operations: InstallmentPlanOperations(
            rateChangesByStage: {
              1: [
                // 重定价日和传入顺序均不决定阶段头部采用哪一条。
                repricing(DateTime.utc(2025, 8, 1), dates.$2, 36000),
                repricing(DateTime.utc(2025, 8, 2), dates.$1, 42000),
                repricing(
                  DateTime.utc(2025, 8, 3),
                  DateTime.utc(2025, 12, 21),
                  30000,
                ),
              ],
              2: [
                repricing(
                  DateTime.utc(2024, 12, 21),
                  DateTime.utc(2024, 12, 21),
                  24000,
                ),
              ],
            },
          ),
        );
        final first = result.entries.first;
        expect(first.interestSegments, hasLength(1));
        expect(first.interestSegments.single.start, DateTime.utc(2025, 9, 1));
        expect(first.interestSegments.single.rate!.ppm, 36000);
        // 9/1 至 12/20 共 111 天，100000 * 3.6% * 111/360 = 1110。
        expect(first.expectedInterest.minorUnits, 111000);
        expect(result.entries[1].interestSegments.single.rate!.ppm, 30000);
        expect(result.entries.last.interestSegments.single.rate!.ppm, 24000);
      },
    );
  }

  test(
    'annual reset on December 21 applies to the complete following period',
    () {
      final result = engine.generate(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 10000000),
          borrowingDate: DateTime.utc(2024, 12, 20),
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime.utc(2025, 12, 20),
                count: 3,
                intervalMonths: 12,
              ),
              method: InstallmentRepaymentMethod.interestFirst,
              rate: const InterestRate(
                ppm: 48000,
                period: InterestRatePeriod.annual,
              ),
              accrual: InterestAccrualMethod.daily,
            ),
          ],
        ),
        operations: InstallmentPlanOperations(
          rateChangesByStage: {
            0: [
              RateChange(
                resetDate: DateTime.utc(2025, 12, 21),
                effectiveDate: DateTime.utc(2025, 12, 21),
                referenceRate: ReferenceRate(
                  type: InterestRateType.lprOneYear,
                  date: DateTime.utc(2025, 12, 20),
                  ratePpm: 36000,
                  source: 'test',
                ),
                spreadBp: 0,
              ),
            ],
          },
        ),
      );
      final nextYear = result.entries[1];
      expect(nextYear.expectedInterest.minorUnits, 365000);
      expect(nextYear.interestSegments, hasLength(1));
      expect(
        nextYear.interestSegments.single.start,
        DateTime.utc(2025, 12, 21),
      );
      expect(nextYear.interestSegments.single.end, DateTime.utc(2026, 12, 21));
    },
  );
  test(
    'repricing preserves the stage end-principal target before the next stage',
    () {
      final result = engine.generate(
        InstallmentPlanTerms(
          principal: const Money(minorUnits: 8000000),
          borrowingDate: start,
          stages: [
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime.utc(2026, 1, 20),
                count: 3,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              rate: const InterestRate(
                ppm: 48000,
                period: InterestRatePeriod.annual,
              ),
              endPrincipal: const Money(minorUnits: 5000000),
            ),
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime.utc(2026, 4, 20),
                count: 5,
              ),
              method: InstallmentRepaymentMethod.equalPrincipal,
              rate: const InterestRate(
                ppm: 36000,
                period: InterestRatePeriod.annual,
              ),
            ),
          ],
        ),
        operations: InstallmentPlanOperations(
          rateChangesByStage: {
            0: [
              RateChange(
                resetDate: effective,
                effectiveDate: effective,
                spreadBp: 0,
                referenceRate: ReferenceRate(
                  date: effective,
                  type: InterestRateType.lprOneYear,
                  ratePpm: 36000,
                  source: 'test',
                ),
              ),
            ],
          },
        ),
      );
      expect(result.stages, hasLength(2));
      expect(result.entries.first.expectedInterest.minorUnits, 27733);
      expect(result.entries[3].expectedInterest.minorUnits, 15000);
      expect(
        result.entries.map((e) => e.expectedPrincipal.minorUnits).toSet(),
        {1000000},
      );
      expect(
        result.entries.fold<int>(
          0,
          (p, e) => p + e.expectedPrincipal.minorUnits,
        ),
        8000000,
      );
    },
  );
  RateChange change(DateTime date, int ratePpm) => RateChange(
    resetDate: DateTime.utc(date.year, date.month, 1),
    effectiveDate: date,
    spreadBp: -30,
    referenceRate: ReferenceRate(
      date: DateTime.utc(date.year, date.month, 1),
      type: InterestRateType.lprFiveYearPlus,
      ratePpm: ratePpm + 3000,
      source: 'test',
    ),
  );
  InstallmentPlan plan({
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.equalInstallment,
    InPeriodRepricingPolicy timing = InPeriodRepricingPolicy.preservePrincipal,
    List<RateChange>? changes,
    InterestAccrualMethod accrual = InterestAccrualMethod.monthly,
    EqualInstallmentAmount amount = const EqualInstallmentAmount.nominalRate(),
    int principalMinor = 8000000,
    int count = 12,
  }) => engine.generate(
    InstallmentPlanTerms(
      principal: Money(minorUnits: principalMinor),
      borrowingDate: start,
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime.utc(2026, 1, 20),
            count: count,
          ),
          method: method,
          rate: const InterestRate(
            ppm: 48000,
            period: InterestRatePeriod.annual,
          ),
          accrual: accrual,
          installmentAmount: amount,
          inPeriodRepricingPolicy: timing,
        ),
      ],
    ),
    operations: InstallmentPlanOperations(
      rateChangesByStage: {
        0: changes ?? [change(effective, 36000)],
      },
    ),
  );

  test(
    '(12/20, 1/20] uses 80000 for both rate segments and rounds only their sum',
    () {
      final result = plan(
        method: InstallmentRepaymentMethod.equalPrincipal,
        count: 4,
      );
      // 80000 * 4.8% * 11/360 + 80000 * 3.6% * 20/360 = 277.333... .
      expect(result.entries.first.expectedInterest.minorUnits, 27733);
      expect(result.entries.first.expectedPrincipal.minorUnits, 2000000);
      expect(result.entries[1].expectedInterest.minorUnits, 18000);
      expect(result.entries.length, 4);
      expect(result.stages.length, 1);
    },
  );

  test(
    'next-period recast preserves transition principal and changes subsequent payment',
    () {
      final before = plan(changes: []);
      final after = plan();
      expect(
        after.entries.first.expectedPrincipal,
        before.entries.first.expectedPrincipal,
      );
      expect(after.entries.first.expectedInterest.minorUnits, 27733);
      final payments = after.entries
          .skip(1)
          .take(10)
          .map(
            (r) =>
                r.expectedPrincipal.minorUnits + r.expectedInterest.minorUnits,
          )
          .toSet();
      expect(payments.length, 1);
      expect(
        payments.single,
        lessThan(
          before.entries[1].expectedPrincipal.minorUnits +
              before.entries[1].expectedInterest.minorUnits,
        ),
      );
      expect(
        after.entries.fold<int>(
          0,
          (p, r) => p + r.expectedPrincipal.minorUnits,
        ),
        8000000,
      );
    },
  );

  test('current-period recast includes mixed first rate in fixed payment', () {
    final result = plan(timing: InPeriodRepricingPolicy.dynamicPeriodRate);
    expect(result.entries.first.expectedInterest.minorUnits, 27733);
    final payments = result.entries
        .take(11)
        .map(
          (r) => r.expectedPrincipal.minorUnits + r.expectedInterest.minorUnits,
        )
        .toSet();
    expect(payments.length, 1);
    expect(
      result.entries.first.expectedPrincipal,
      isNot(plan(changes: []).entries.first.expectedPrincipal),
    );
    expect(
      result.entries.fold<int>(0, (p, r) => p + r.expectedPrincipal.minorUnits),
      8000000,
    );
  });

  test('actual-rate recast accounts for differing day lengths', () {
    final result = plan(
      timing: InPeriodRepricingPolicy.dynamicPeriodRate,
      accrual: InterestAccrualMethod.daily,
      amount: const EqualInstallmentAmount.actualRate(),
    );
    final payments = result.entries
        .take(11)
        .map(
          (r) => r.expectedPrincipal.minorUnits + r.expectedInterest.minorUnits,
        )
        .toSet();
    expect(payments.length, 1);
    expect(result.entries.first.expectedInterest.minorUnits, 27733);
    expect(
      payments.single,
      isNot(
        plan(
              timing: InPeriodRepricingPolicy.dynamicPeriodRate,
            ).entries.first.expectedPrincipal.minorUnits +
            27733,
      ),
    );
  });

  test(
    'repricing the day after repayment starts the following accrual period',
    () {
      final result = plan(changes: [change(DateTime.utc(2026, 1, 21), 36000)]);
      final before = plan(changes: []);
      expect(
        result.entries.first.expectedPrincipal,
        before.entries.first.expectedPrincipal,
      );
      expect(
        result.entries.first.expectedInterest,
        before.entries.first.expectedInterest,
      );
      expect(
        result.entries[1].expectedPrincipal,
        isNot(before.entries[1].expectedPrincipal),
      );
    },
  );

  test(
    'period opening repricing does not use either in-period payment policy',
    () {
      for (final accrual in [
        InterestAccrualMethod.daily,
        InterestAccrualMethod.monthly,
      ]) {
        final changes = [change(DateTime.utc(2026, 1, 21), 36000)];
        final preserve = plan(changes: changes, accrual: accrual);
        final dynamic = plan(
          changes: changes,
          accrual: accrual,
          timing: InPeriodRepricingPolicy.dynamicPeriodRate,
        );
        expect(
          preserve.entries.map(
            (row) => (row.expectedPrincipal, row.expectedInterest),
          ),
          dynamic.entries.map(
            (row) => (row.expectedPrincipal, row.expectedInterest),
          ),
        );
        expect(preserve.entries[1].interestSegments, hasLength(1));
        expect(preserve.entries[1].interestSegments.single.accrual, accrual);
      }
    },
  );

  test(
    'repricing on repayment day changes the final accrual day of that period',
    () {
      final result = plan(
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrual: InterestAccrualMethod.daily,
        count: 4,
        changes: [change(DateTime.utc(2026, 1, 20), 36000)],
      );
      // (12/20, 1/20]: 30 old-rate days and one new-rate day.
      expect(result.entries.first.expectedInterest.minorUnits, 32800);
      expect(
        result.entries.first.interestSegments.last.start,
        DateTime.utc(2026, 1, 20),
      );
      expect(
        result.entries.first.interestSegments.last.end,
        DateTime.utc(2026, 1, 21),
      );
    },
  );

  test(
    'future referenceRate does not influence payments before its effective period',
    () {
      final first = plan();
      final second = plan(
        changes: [
          change(effective, 36000),
          change(DateTime.utc(2026, 4, 1), 30000),
        ],
      );
      for (var i = 0; i < 3; i++) {
        expect(
          second.entries[i].expectedPrincipal,
          first.entries[i].expectedPrincipal,
        );
        expect(
          second.entries[i].expectedInterest,
          first.entries[i].expectedInterest,
        );
      }
      expect(
        second.entries[3].expectedPrincipal,
        first.entries[3].expectedPrincipal,
      );
      expect(
        second.entries[4].expectedPrincipal +
            second.entries[4].expectedInterest,
        isNot(
          first.entries[4].expectedPrincipal +
              first.entries[4].expectedInterest,
        ),
      );
    },
  );

  test(
    'unchanged rate does not convert a normal monthly period into daily accrual',
    () {
      final result = plan(changes: [change(effective, 48000)]);
      expect(
        result.entries.first.expectedInterest,
        plan(changes: []).entries.first.expectedInterest,
      );
    },
  );

  for (final (accrual, dayCount, annualPpm) in [
    (InterestAccrualMethod.monthly, DayCountConvention.thirty365, 36000),
    (InterestAccrualMethod.annual, DayCountConvention.thirty365, 36000),
    (InterestAccrualMethod.daily, DayCountConvention.thirty360, 36000),
    (InterestAccrualMethod.daily, DayCountConvention.thirty365, 36500),
  ]) {
    for (final date in [effective, DateTime.utc(2026, 1, 21)]) {
      test(
        'equivalent ${accrual.name} rate with $dayCount on $date keeps the plan',
        () {
          final terms = InstallmentPlanTerms(
            principal: const Money(minorUnits: 8000000),
            borrowingDate: start,
            dayCount: dayCount,
            stages: [
              AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime.utc(2026, 1, 20),
                  count: 3,
                ),
                method: InstallmentRepaymentMethod.equalInstallment,
                rate: const InterestRate(
                  ppm: 3000,
                  period: InterestRatePeriod.monthly,
                ),
                accrual: accrual,
                installmentAmount: const EqualInstallmentAmount.actualRate(),
              ),
            ],
          );
          final before = engine.generate(terms);
          final after = engine.generate(
            terms,
            operations: InstallmentPlanOperations(
              rateChangesByStage: {
                0: [change(date, annualPpm)],
              },
            ),
          );
          expect(
            after.entries.map((e) => (e.expectedPrincipal, e.expectedInterest)),
            before.entries.map(
              (e) => (e.expectedPrincipal, e.expectedInterest),
            ),
          );
          expect(
            after.entries.every(
              (e) =>
                  e.interestSegments.length == 1 &&
                  e.interestSegments.single.accrual == accrual,
            ),
            isTrue,
          );
          // 仅单位改变不触发固定还款额重算，也不使固定额汇总失效。
          expect(
            after.stages.single.installmentAmount,
            before.stages.single.installmentAmount,
          );
        },
      );
    }
  }

  test(
    'a later real change keeps the earlier effective rate facts for daily segments',
    () {
      final terms = InstallmentPlanTerms(
        principal: const Money(minorUnits: 10000000),
        borrowingDate: start,
        dayCount: DayCountConvention.thirty365,
        stages: [
          AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime.utc(2026, 1, 20),
              count: 2,
            ),
            method: InstallmentRepaymentMethod.interestFirst,
            rate: const InterestRate(
              ppm: 3000,
              period: InterestRatePeriod.monthly,
            ),
            accrual: InterestAccrualMethod.monthly,
          ),
        ],
      );
      final result = engine.generate(
        terms,
        operations: InstallmentPlanOperations(
          rateChangesByStage: {
            0: [
              change(effective, 36000),
              change(DateTime.utc(2026, 1, 10), 48000),
            ],
          },
        ),
      );
      // 100000 * (0.3%/30*11 + 3.6%/365*9 + 4.8%/365*11) = 343.42465...
      expect(result.entries.first.expectedInterest.minorUnits, 34342);
      expect(
        result.entries.first.interestSegments.map(
          (s) => (s.rate!.ppm, s.rate!.period),
        ),
        [
          (3000, InterestRatePeriod.monthly),
          (36000, InterestRatePeriod.annual),
          (48000, InterestRatePeriod.annual),
        ],
      );
      expect(result.entries[1].expectedInterest.minorUnits, 40000);
    },
  );

  test('daily comparison respects 365 days and exact rate differences', () {
    final terms = InstallmentPlanTerms(
      principal: const Money(minorUnits: 10000000),
      borrowingDate: start,
      dayCount: DayCountConvention.thirty365,
      stages: [
        AmortizingStage(
          dates: IntervalRepaymentDates(
            firstDate: DateTime.utc(2026, 1, 20),
            count: 2,
          ),
          method: InstallmentRepaymentMethod.interestFirst,
          rate: const InterestRate(
            ppm: 3000,
            period: InterestRatePeriod.monthly,
          ),
          accrual: InterestAccrualMethod.daily,
        ),
      ],
    );
    final result = engine.generate(
      terms,
      operations: InstallmentPlanOperations(
        rateChangesByStage: {
          0: [change(effective, 36000)],
        },
      ),
    );
    // 100000 * (0.3% / 30 * 11 + 3.6% / 365 * 20) = 307.26027...
    expect(result.entries.first.expectedInterest.minorUnits, 30726);
    expect(result.entries.first.interestSegments, hasLength(2));
    final tiny = engine.generate(
      terms,
      operations: InstallmentPlanOperations(
        rateChangesByStage: {
          0: [change(effective, 36501)],
        },
      ),
    );
    expect(tiny.entries.first.interestSegments, hasLength(2));
    expect(tiny.entries.first.interestSegments.last.rate!.ppm, 36501);
  });
}
