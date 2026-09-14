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
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';

void main() {
  const engine = InstallmentPlanEngine();
  final start = DateTime.utc(2025, 12, 20);
  final effective = DateTime.utc(2026, 1, 1);
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
      expect(result.entries.first.expectedInterest.minorUnits, 28000);
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
    '12/20–1/20 uses 80000 for both rate segments and rounds only their sum',
    () {
      final result = plan(
        method: InstallmentRepaymentMethod.equalPrincipal,
        count: 4,
      );
      // 80000 * 4.8% * 12/360 + 80000 * 3.6% * 19/360 = 280.
      expect(result.entries.first.expectedInterest.minorUnits, 28000);
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
      expect(after.entries.first.expectedInterest.minorUnits, 28000);
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
    expect(result.entries.first.expectedInterest.minorUnits, 28000);
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
    expect(result.entries.first.expectedInterest.minorUnits, 28000);
    expect(
      payments.single,
      isNot(
        plan(
              timing: InPeriodRepricingPolicy.dynamicPeriodRate,
            ).entries.first.expectedPrincipal.minorUnits +
            28000,
      ),
    );
  });

  test('repricing on repayment date belongs to following accrual period', () {
    final result = plan(changes: [change(DateTime.utc(2026, 1, 20), 36000)]);
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
  });

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
}
