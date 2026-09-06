import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/equal_installment_amount.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

void main() {
  const recalculator = InstallmentPrepaymentRecalculator();
  test(
    'caps stage two balance, keeps interest and fees, and passes balance to stage three',
    () {
      final aggregate = _loan();
      final original = aggregate.schedules;
      original[0].markPaid();
      final result = recalculator.recalculate(
        contract: aggregate.contract,
        schedules: original,
        prepaymentPrincipalMinor: 5000000,
        eventDate: DateTime(2026, 2, 15),
      );
      expect(result.map((r) => r.scheduleId), [
        original[1].id,
        original[2].id,
        original[3].id,
      ]);
      expect(result.first.expectedPrincipal.minorUnits, 0);
      expect(result.first.expectedInterest.minorUnits, 40000);
      expect(result.first.expectedFee.minorUnits, 1000);
      expect(result.skip(1).map((r) => r.expectedPrincipal.minorUnits), [
        2000000,
        2000000,
      ]);
      expect(result.skip(1).map((r) => r.expectedInterest.minorUnits), [
        80000,
        40000,
      ]);
      expect(original.first.expectedPrincipal.minorUnits, 1000000);
      expect(
        (aggregate.contract.stageTerms.stages[1].terms as AmortizingStage)
            .endPrincipal!
            .minorUnits,
        5000000,
      );
      for (var i = 0; i < result.length; i++) {
        expect(
          result[i].expectedRepaymentDate,
          original[i + 1].expectedRepaymentDate,
        );
      }
      final restored = recalculator.recalculate(
        contract: aggregate.contract,
        schedules: original,
        prepaymentPrincipalMinor: 0,
        eventDate: DateTime(2026, 2, 15),
      );
      expect(restored.first.expectedPrincipal.minorUnits, 4000000);
      expect(restored.skip(1).map((r) => r.expectedPrincipal.minorUnits), [
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
      final result = recalculator.recalculate(
        contract: aggregate.contract,
        schedules: aggregate.schedules,
        prepaymentPrincipalMinor: 5000000,
        eventDate: DateTime(2026, 2, 15),
      );
      expect(result.first.expectedPrincipal.minorUnits, 0);
      expect(result.first.expectedInterest.minorUnits, greaterThan(0));
    },
  );

  test('prepayment during deferment preserves interest-free timeline', () {
    final aggregate = _loan();
    final result = recalculator.recalculate(
      contract: aggregate.contract,
      schedules: aggregate.schedules,
      prepaymentPrincipalMinor: 1000000,
      eventDate: DateTime(2025, 12, 15),
    );
    expect(result.length, 4);
    expect(result.first.expectedRepaymentDate, DateTime(2026, 2, 1));
    expect(
      result.fold<int>(0, (n, r) => n + r.expectedPrincipal.minorUnits),
      9000000,
    );
  });

  test('a later non-pending stage advances the anchor', () {
    final aggregate = _loan();
    aggregate.schedules[2].skip();
    final result = recalculator.recalculate(
      contract: aggregate.contract,
      schedules: aggregate.schedules,
      prepaymentPrincipalMinor: 1000000,
      eventDate: DateTime(2026, 2, 15),
    );
    expect(result.single.scheduleId, aggregate.schedules.last.id);
    expect(result.single.expectedPrincipal.minorUnits, 1500000);
  });

  test('final balloon repays capped balance in final period', () {
    final aggregate = _loan(balloon: true);
    aggregate.schedules[2].markPaid();
    final frozenPrincipal = aggregate.schedules
        .take(3)
        .fold<int>(0, (n, s) => n + s.expectedPrincipal.minorUnits);
    final result = recalculator.recalculate(
      contract: aggregate.contract,
      schedules: aggregate.schedules,
      prepaymentPrincipalMinor: 10000000 - frozenPrincipal - 1000000,
    );
    expect(result.single.expectedPrincipal.minorUnits, 1000000);
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
