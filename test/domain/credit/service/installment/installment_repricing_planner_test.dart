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
