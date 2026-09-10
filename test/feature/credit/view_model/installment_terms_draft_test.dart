import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';

void main() {
  test(
    'floating configuration round trip preserves signed BP, timing and calendar anchors',
    () {
      final draft = InstallmentStageDraft(
        id: 'floating',
        floating: true,
        referenceRateType: ReferenceRateType.loanBenchmarkLongTerm,
        firstDate: DateTime(2026, 1, 20),
        firstResetDate: DateTime(2025, 12, 20),
        firstEffectiveDate: DateTime(2026, 1, 1),
        repricingCycleMonths: 6,
        inputs: const {
          StageInput.rate: '3.2',
          StageInput.spreadBp: '-30',
          StageInput.interval: '1',
          StageInput.periods: '120',
        },
      );
      final terms = InstallmentTermsDraft(stages: [draft]).contractTerms();
      final reopened = InstallmentTermsDraft.contract(terms).stages.single;
      expect(reopened.floating, isTrue);
      expect(
        reopened.referenceRateType,
        ReferenceRateType.loanBenchmarkLongTerm,
      );
      expect(reopened.text(StageInput.spreadBp), '-30');
      expect(reopened.repricingCycleMonths, 6);
      expect(
        reopened.repricingPaymentTiming,
        RepricingPaymentTiming.nextPeriod,
      );
      expect(reopened.firstEffectiveDate, DateTime(2026, 1, 1));
      expect(reopened.toContractStage().terms, isA<AmortizingStage>());
      final flat = reopened.changeMethod(InstallmentRepaymentMethod.flatFee);
      expect(flat.floating, isFalse);
      expect(
        (flat.toContractStage().terms as AmortizingStage).floatingRate,
        isNull,
      );
    },
  );
  test('adding a stage follows the actual last date and clamps month ends', () {
    final draft = InstallmentTermsDraft.loan(DateTime(2026, 1, 31));
    expect(draft.stages.single.firstDate, DateTime(2026, 2, 28));
    final next = draft.add(false, borrowingDate: DateTime(2026, 1, 31));
    expect(next.stages.last.firstDate, DateTime(2027, 2, 28));
    expect(next.stages.map((s) => s.id).toSet(), hasLength(2));
    expect(draft.stages, hasLength(1));
  });
  test('product rules do not depend on any loan amount or date', () {
    final draft = InstallmentTermsDraft.initial();
    final rule = draft.productRules().single;
    expect(rule.intervalMonths, 1);
    expect(rule.amountAlgorithm, InstallmentAmountAlgorithm.nominalRate);
    expect(() => draft.contractTerms(), throwsA(isA<Exception>()));
  });
  test(
    'one-time fee clears hidden recurring fields without losing the fee',
    () {
      final stage = InstallmentStageDraft(
        id: 'one',
        lastDate: DateTime(2027, 1, 1),
        inputs: const {
          StageInput.periods: '12',
          StageInput.interval: '3',
          StageInput.rate: '12',
          StageInput.fixedAmount: '100',
          StageInput.fee: '88',
        },
      ).changeMethod(InstallmentRepaymentMethod.flatFee);
      expect(stage.lastDate, isNull);
      expect(stage.text(StageInput.periods), '1');
      expect(stage.text(StageInput.rate), isEmpty);
      expect(stage.text(StageInput.fixedAmount), isEmpty);
      expect(stage.text(StageInput.fee), '88');
    },
  );
  test('changing fixed amount algorithm clears only the fixed amount', () {
    final stage = InstallmentStageDraft(
      id: 'one',
      algorithm: InstallmentAmountAlgorithm.fixed,
      inputs: const {StageInput.fixedAmount: '100', StageInput.fee: '88'},
    ).changeAlgorithm(InstallmentAmountAlgorithm.actualRate);
    expect(stage.text(StageInput.fixedAmount), isEmpty);
    expect(stage.text(StageInput.fee), '88');
  });
  test(
    'contract round trip preserves conventions, algorithm and stage identity',
    () {
      final original = InstallmentContractTerms(
        dayCount: DayCountConvention.thirty365,
        rounding: RoundingMode.halfEven,
        stages: [
          InstallmentContractStage(
            id: 'owned-stage',
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: DateTime(2026, 4, 30),
                count: 4,
                intervalMonths: 3,
              ),
              method: InstallmentRepaymentMethod.equalInstallment,
              accrual: InterestAccrualMethod.daily,
              rate: InterestRate(ppm: 2900, period: InterestRatePeriod.monthly),
              fee: const Money(minorUnits: 123),
              installmentAmount: const EqualInstallmentAmount.actualRate(),
            ),
          ),
        ],
      );
      final actual = InstallmentTermsDraft.contract(original).contractTerms();
      expect(actual.dayCount, original.dayCount);
      expect(actual.rounding, original.rounding);
      expect(actual.stages.single.id, 'owned-stage');
      expect(actual.repayments.single.rate!.ppm, 2900);
      expect(
        actual.repayments.single.installmentAmount,
        isA<ActualRateInstallmentAmount>(),
      );
      expect(
        actual.repayments.single.dates.getDates(),
        original.repayments.single.dates.getDates(),
      );
      expect(actual.totalFeeMinor, 123);
    },
  );
  test(
    'interest-free contract keeps its selected rate unit after reopening',
    () {
      final base = InstallmentTermsDraft.loan(DateTime(2026, 1, 1));
      final stage = base.stages.single.copyWith(
        ratePeriod: InterestRatePeriod.daily,
      );
      final reopened = InstallmentTermsDraft.contract(
        base.replace(stage).contractTerms(),
      );
      expect(reopened.stages.single.ratePeriod, InterestRatePeriod.daily);
      expect(reopened.contractTerms().repayments.single.rate!.ppm, 0);
    },
  );
  test(
    'ordinary stages accept fees and reject negative or non-finite input',
    () {
      final base = InstallmentTermsDraft.loan(DateTime(2026, 1, 1));
      final stage = base.stages.single.setInput(StageInput.fee, '12');
      expect(base.replace(stage).contractTerms().totalFeeMinor, 1200);
      for (final value in ['NaN', 'Infinity', '-1', 'bad']) {
        expect(
          () => base
              .replace(stage.setInput(StageInput.rate, value))
              .contractTerms(),
          throwsA(isA<Exception>()),
          reason: value,
        );
      }
    },
  );
  test(
    'moving stages keeps their identity and input and validates timeline',
    () {
      final base = InstallmentTermsDraft.loan(
        DateTime(2026, 1, 1),
      ).add(false, borrowingDate: DateTime(2026, 1, 1));
      final moved = base.move(0, 1);
      expect(moved.stages.last, same(base.stages.first));
      expect(() => moved.contractTerms(), throwsA(isA<Exception>()));
      expect(
        base.remove(base.stages.last.id).remove(base.stages.first.id).stages,
        hasLength(1),
      );
    },
  );
}
