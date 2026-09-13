import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/presentation/installment_stage_presentation.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';

void main() {
  for (final (effectiveDate, secondStageRate) in [
    (DateTime(2026, 3, 15), 18000),
    (DateTime(2026, 6, 1), 60000),
  ]) {
    test(
      'current rate stays within its stage when repricing starts $effectiveDate',
      () {
        InstallmentRepricingReadModel repricing(
          String stageId,
          DateTime date,
          int ratePpm,
        ) => InstallmentRepricingReadModel(
          id: 'repricing-$stageId',
          stageId: stageId,
          status: InstallmentRepricingStatus.applied,
          change: RateChange(
            resetDate: date,
            effectiveDate: date,
            spreadBp: 0,
            referenceRate: ReferenceRate(
              date: date.subtract(const Duration(days: 1)),
              type: ReferenceRateType.lprOneYear,
              ratePpm: ratePpm,
              source: 'test',
            ),
          ),
        );
        final contract = InstallmentContractReadModel(
          id: 'contract',
          liabilityAccountId: 'loan',
          sourceType: InstallmentSourceType.disbursement,
          principal: const Money(minorUnits: 100000),
          borrowingDate: DateTime(2026, 1, 1),
          status: InstallmentContractStatus.active,
          createdAt: DateTime(2026, 1, 1),
          stageTerms: InstallmentContractTerms(
            stages: [
              InstallmentContractStage(
                id: 'first',
                terms: AmortizingStage(
                  dates: IntervalRepaymentDates(
                    firstDate: DateTime(2026, 2, 1),
                    count: 3,
                  ),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                  endPrincipal: const Money(minorUnits: 50000),
                  rate: const InterestRate(
                    ppm: 48000,
                    period: InterestRatePeriod.annual,
                  ),
                ),
              ),
              InstallmentContractStage(
                id: 'second',
                terms: AmortizingStage(
                  dates: IntervalRepaymentDates(
                    firstDate: DateTime(2026, 5, 1),
                    count: 3,
                  ),
                  method: InstallmentRepaymentMethod.equalPrincipal,
                  rate: const InterestRate(
                    ppm: 60000,
                    period: InterestRatePeriod.annual,
                  ),
                ),
              ),
            ],
          ),
          repricings: [
            repricing('first', DateTime(2026, 3, 1), 36000),
            repricing('second', effectiveDate, 18000),
          ],
        );

        expect(installmentRateOn(contract, DateTime(2026, 3, 20))?.ppm, 36000);
        expect(
          installmentRateOn(contract, DateTime(2026, 5, 20))?.ppm,
          secondStageRate,
        );
        expect(installmentRateOn(contract, DateTime(2026, 6, 20))?.ppm, 18000);
      },
    );
  }

  test('presents automatic end dates and rate units without a widget', () {
    final stage = InstallmentStageDraft(
      id: 'stage-1',
      firstDate: DateTime(2026, 2, 28),
      inputs: const {
        StageInput.periods: '3',
        StageInput.interval: '1',
        StageInput.rate: '1.5',
      },
    );

    final presentation = presentInstallmentStageSummary(
      stage: stage,
      index: 0,
      stages: [stage],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 15),
    );

    expect(presentation.endDate, DateTime(2026, 4, 28));
    expect(presentation.lines.first, contains('年利率 1.5%'));
    expect(presentation.lines.last, '2026-01-15 → 2026-04-28');
  });

  test('uses placeholders for incomplete stages and handles deferment', () {
    final stage = InstallmentStageDraft(
      id: 'stage-1',
      inputs: const {StageInput.interval: '1'},
    );
    final deferment = InstallmentStageDraft(
      id: 'stage-2',
      deferment: true,
      untilDate: DateTime(2026, 3, 1),
    );

    final incomplete = presentInstallmentStageSummary(
      stage: stage,
      index: 0,
      stages: [stage],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 1),
    );
    final deferred = presentInstallmentStageSummary(
      stage: deferment,
      index: 1,
      stages: [stage, deferment],
      productMode: false,
      borrowingDate: DateTime(2026, 1, 1),
    );

    expect(incomplete.lines, contains('等额本息 · 年利率 0%'));
    expect(incomplete.lines.last, '2026-01-01 → 结束日期待确定');
    expect(deferred.lines, ['不还款、不计息', '起点待确定 → 2026-03-01']);
  });
}
