import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/entity/installment_repricing_configuration.dart';
import 'package:smartflow/domain/credit/service/installment/installment_repricing_planner.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_terms.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

void main() {
  test('completion uses the next reset ownership and effective stage end', () {
    final terms = InstallmentContractTerms(
      stages: [
        InstallmentContractStage(
          id: 'stage',
          terms: AmortizingStage(
            dates: IntervalRepaymentDates(firstDate: date(12, 20), count: 1),
            method: InstallmentRepaymentMethod.interestFirst,
          ),
        ),
      ],
    );
    List<String> completed(List<InstallmentRepricingConfiguration> values) =>
        const InstallmentRepricingPlanner()
            .completed(
              configurations: values,
              borrowingDate: date(1, 1),
              terms: terms,
            )
            .map((c) => c.id)
            .toList();
    final first = configuration(
      'first',
      from: date(1, 1),
      reset: date(3, 20),
      effective: date(3, 21),
    );
    final next = configuration(
      'next',
      from: date(3, 20),
      reset: date(6, 20),
      effective: date(6, 21),
    );
    // 未来有效周期仍待生成；即使后续配置已完成，仍保留其归属边界。
    expect(completed([first]), isEmpty);
    expect(completed([first, next.withGenerationCompleted(true)]), ['first']);
    // 重定价日在阶段内，但生效日晚于末期，也无须生成。
    expect(
      completed([
        configuration(
          'beyond-end',
          from: date(1, 1),
          reset: date(12, 20),
          effective: date(12, 21),
        ),
      ]),
      ['beyond-end'],
    );
    // 末日仍计息；本周期尚未成功处理时不得提前完成。
    expect(
      completed([
        configuration(
          'last-day',
          from: date(1, 1),
          reset: date(12, 19),
          effective: date(12, 20),
        ),
      ]),
      isEmpty,
    );
    expect(
      completed([
        configuration(
          'last-day',
          from: date(1, 1),
          reset: date(12, 19),
          effective: date(12, 20),
          last: date(12, 19),
        ),
      ]),
      ['last-day'],
    );
  });

  test('progress resumes from the calendar anchor without month-end drift', () {
    final rule = FloatingRateRule(
      referenceRateType: InterestRateType.lprOneYear,
      spreadBp: 0,
      firstResetDate: DateTime.utc(2000, 8, 31),
      firstEffectiveDate: DateTime.utc(2000, 9, 1),
      cycleMonths: 6,
    );
    expect(
      rule.resetDate(rule.resetCycleOnOrAfter(DateTime.utc(2026, 2, 28))),
      DateTime.utc(2026, 2, 28),
    );
    expect(
      rule.resetDate(rule.resetCycleOnOrAfter(DateTime.utc(2026, 3, 1))),
      DateTime.utc(2026, 8, 31),
    );
  });

  test('student loan configurations generate resets before their stages', () {
    final terms = InstallmentContractTerms(
      stages: [
        InstallmentContractStage(
          id: 'deferment',
          terms: DefermentStage(until: DateTime.utc(2025, 8, 31)),
        ),
        InstallmentContractStage(
          id: 'interest',
          terms: AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime.utc(2025, 12, 20),
              count: 5,
              intervalMonths: 12,
            ),
            method: InstallmentRepaymentMethod.interestFirst,
          ),
        ),
        InstallmentContractStage(
          id: 'principal',
          terms: AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime.utc(2030, 12, 20),
              count: 1,
            ),
            method: InstallmentRepaymentMethod.equalPrincipal,
          ),
        ),
      ],
    );
    List<InstallmentRepricingCandidate> generate(
      DateTime now, {
      DateTime? last,
    }) => const InstallmentRepricingPlanner().due(
      configurations: [
        for (final stageId in ['interest', 'principal'])
          InstallmentRepricingConfiguration(
            id: stageId,
            contractId: 'loan',
            stageId: stageId,
            effectiveFrom: DateTime.utc(2024, 10, 31),
            lastGeneratedDate: last,
            rule: FloatingRateRule(
              referenceRateType: InterestRateType.lprFiveYearPlus,
              spreadBp: 0,
              firstResetDate: DateTime.utc(2024, 12, 21),
              firstEffectiveDate: DateTime.utc(2024, 12, 21),
              cycleMonths: 12,
            ),
          ),
      ],
      borrowingDate: DateTime.utc(2024, 9, 1),
      terms: terms,
      now: now,
    );

    final candidates = generate(DateTime.utc(2026, 9, 15));
    for (final stageId in ['interest', 'principal']) {
      expect(
        candidates
            .where((c) => c.configuration.stageId == stageId)
            .map((c) => c.resetDate),
        [DateTime.utc(2024, 12, 21), DateTime.utc(2025, 12, 21)],
      );
    }
    // 已处理的进度不回退，不补建此前被旧逻辑遗漏的记录。
    expect(
      generate(DateTime.utc(2026, 9, 15), last: DateTime.utc(2025, 12, 21)),
      isEmpty,
    );
    final finished = generate(DateTime.utc(2031));
    expect(
      finished
          .where((c) => c.configuration.stageId == 'interest')
          .last
          .resetDate,
      DateTime.utc(2028, 12, 21),
    );
    expect(
      finished
          .where((c) => c.configuration.stageId == 'principal')
          .last
          .resetDate,
      DateTime.utc(2029, 12, 21),
    );
  });

  List<InstallmentRepricingCandidate> due(
    List<InstallmentRepricingConfiguration> configurations,
    DateTime now,
  ) => const InstallmentRepricingPlanner().due(
    configurations: configurations,
    borrowingDate: DateTime.utc(2025, 6, 20),
    terms: InstallmentContractTerms(
      stages: [
        InstallmentContractStage(
          id: 'stage',
          terms: AmortizingStage(
            dates: IntervalRepaymentDates(
              firstDate: DateTime.utc(2026, 6, 20),
              count: 3,
              intervalMonths: 12,
            ),
            method: InstallmentRepaymentMethod.interestFirst,
          ),
        ),
      ],
    ),
    now: now,
  );

  test('a June 20 reset belongs to the configuration ending June 21', () {
    final first = configuration(
      'first',
      from: date(5, 1),
      reset: date(6, 20),
      effective: date(6, 21),
    );
    final second = configuration(
      'second',
      from: date(6, 21),
      reset: date(12, 20),
      effective: date(12, 21),
    );
    final candidates = due([second, first], date(6, 20));
    expect(candidates, hasLength(1));
    expect(candidates.single.configuration.id, 'first');
    expect(candidates.single.resetDate, date(6, 20));
    expect(candidates.single.effectiveDate, date(6, 21));
  });

  test('a configuration cannot generate a reset before its own start', () {
    final value = configuration(
      'future',
      from: date(6, 21),
      reset: date(6, 20),
      effective: date(6, 21),
    );
    expect(due([value], date(6, 21)), isEmpty);
  });

  test('each configuration resumes after its own last processed reset', () {
    final first = configuration(
      'first',
      from: date(1, 1),
      reset: date(1, 31),
      effective: date(2, 1),
      last: date(1, 31),
    );
    final second = configuration(
      'second',
      from: date(6, 1),
      reset: date(7, 1),
      effective: date(7, 2),
    );
    final third = configuration(
      'third',
      from: date(11, 1),
      reset: date(11, 1),
      effective: date(11, 2),
    );
    expect(
      due([third, second, first], date(10, 1)).map(
        (candidate) => (
          candidate.configuration.id,
          candidate.resetDate,
          candidate.effectiveDate,
        ),
      ),
      [
        ('first', date(4, 30), date(5, 1)),
        ('second', date(7, 1), date(7, 2)),
        ('second', date(10, 1), date(10, 2)),
      ],
    );
  });

  test('the next configuration owns a reset on the shared boundary', () {
    final first = configuration(
      'first',
      from: date(1, 1),
      reset: date(6, 21),
      effective: date(6, 22),
    );
    final second = configuration(
      'second',
      from: date(6, 21),
      reset: date(6, 21),
      effective: date(6, 23),
    );
    final candidates = due([first, second], date(6, 21));
    expect(candidates, hasLength(1));
    expect(candidates.single.configuration.id, 'second');
  });
}

DateTime date(int month, int day) => DateTime.utc(2026, month, day);

InstallmentRepricingConfiguration configuration(
  String id, {
  required DateTime from,
  required DateTime reset,
  required DateTime effective,
  DateTime? last,
}) => InstallmentRepricingConfiguration(
  id: id,
  contractId: 'loan',
  stageId: 'stage',
  effectiveFrom: from,
  lastGeneratedDate: last,
  rule: FloatingRateRule(
    referenceRateType: InterestRateType.lprOneYear,
    spreadBp: 0,
    firstResetDate: reset,
    firstEffectiveDate: effective,
    cycleMonths: 3,
  ),
);
