import 'package:drift/drift.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../domain/credit/valobj/day_count_convention.dart';
import '../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../../domain/credit/valobj/equal_installment_amount.dart';
import '../../../domain/credit/valobj/interest_rate.dart';
import '../../../domain/credit/valobj/floating_rate.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../domain/credit/valobj/repayment_dates_strategy.dart';
import '../../database/app_database.dart';
import '../../../domain/credit/entity/installment_repricing_configuration.dart';
import '../../../domain/credit/entity/installment_interest_adjustment.dart';
import '../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../domain/credit/valobj/tail_difference_policy.dart';

String encodeDayCount(DayCountConvention value) =>
    value == DayCountConvention.thirty365 ? 'thirty365' : 'thirty360';
DayCountConvention decodeDayCount(String value) => switch (value) {
  'thirty360' => DayCountConvention.thirty360,
  'thirty365' => DayCountConvention.thirty365,
  _ => throw FormatException('Unknown day count: $value'),
};

InstallmentContractTerms decodeContractTerms(
  List<InstallmentStageConfigRow> rows, {
  required String dayCount,
  required String rounding,
}) => InstallmentContractTerms(
  dayCount: decodeDayCount(dayCount),
  rounding: RoundingMode.values.byName(rounding),
  stages: [
    for (final row in rows)
      InstallmentContractStage(
        id: row.id,
        terms: row.stageKind == 'deferment'
            ? DefermentStage(until: row.endDate)
            : AmortizingStage(
                inPeriodRepricingPolicy: row.inPeriodRepricingPolicy == null
                    ? InPeriodRepricingPolicy.preservePrincipal
                    : InPeriodRepricingPolicy.values.byName(
                        row.inPeriodRepricingPolicy!,
                      ),
                tailDifference: TailDifferencePolicy.values.byName(
                  row.tailDifference!,
                ),
                dates: IntervalRepaymentDates(
                  firstDate: row.firstDate!,
                  count: row.periods!,
                  lastDate: row.endDate,
                  intervalMonths: row.intervalMonths ?? 1,
                ),
                method: InstallmentRepaymentMethod.values.byName(
                  row.repaymentMethod!,
                ),
                rate: row.initialRatePpm == null
                    ? null
                    : InterestRate(
                        ppm: row.initialRatePpm!,
                        period: InterestRatePeriod.values.byName(
                          row.ratePeriod!,
                        ),
                      ),
                accrual: row.accrual == null
                    ? InterestAccrualMethod.monthly
                    : InterestAccrualMethod.values.byName(row.accrual!),
                accrualStartDate: row.accrualStartDate,
                endPrincipal: row.endPrincipalMinor == null
                    ? null
                    : Money(minorUnits: row.endPrincipalMinor!),
                fee: Money(minorUnits: row.feeMinor ?? 0),
                installmentAmount: switch (row.amountAlgorithm) {
                  'fixed' => EqualInstallmentAmount.fixed(
                    Money(minorUnits: row.fixedAmountMinor!),
                  ),
                  'actualRate' => const EqualInstallmentAmount.actualRate(),
                  _ => const EqualInstallmentAmount.nominalRate(),
                },
              ),
      ),
  ],
);

InstallmentStageRule decodeProductStage(InstallmentProductStageConfigRow row) =>
    row.stageKind == 'deferment'
    ? InstallmentStageRule.deferment(id: row.id)
    : InstallmentStageRule.repayment(
        id: row.id,
        method: InstallmentRepaymentMethod.values.byName(row.repaymentMethod!),
        intervalMonths: row.intervalMonths,
        ratePeriod: row.ratePeriod == null
            ? null
            : InterestRatePeriod.values.byName(row.ratePeriod!),
        accrual: row.accrual == null
            ? null
            : InterestAccrualMethod.values.byName(row.accrual!),
        amountAlgorithm: row.amountAlgorithm == null
            ? null
            : InstallmentAmountAlgorithm.values.byName(row.amountAlgorithm!),
        rateType: row.rateType == null
            ? InterestRateType.fixed
            : InterestRateType.values.byName(row.rateType!),
        repricingCycleMonths: row.repricingCycleMonths ?? 12,
        inPeriodRepricingPolicy: row.inPeriodRepricingPolicy == null
            ? InPeriodRepricingPolicy.preservePrincipal
            : InPeriodRepricingPolicy.values.byName(
                row.inPeriodRepricingPolicy!,
              ),
        tailDifference: TailDifferencePolicy.values.byName(row.tailDifference!),
      );

InstallmentProductStageConfigsCompanion encodeProductStage(
  InstallmentStageRule rule,
  String ownerId,
  int position,
) => InstallmentProductStageConfigsCompanion.insert(
  id: rule.id,
  productId: ownerId,
  position: position,
  stageKind: rule.kind.name,
  repaymentMethod: Value(rule.method?.name),
  intervalMonths: Value(rule.intervalMonths),
  ratePeriod: Value(rule.ratePeriod?.name),
  accrual: Value(rule.accrual?.name),
  amountAlgorithm: Value(rule.amountAlgorithm?.name),
  rateType: Value(rule.rateType?.name),
  repricingCycleMonths: Value(rule.repricingCycleMonths),
  inPeriodRepricingPolicy: Value(rule.inPeriodRepricingPolicy?.name),
  tailDifference: Value(rule.tailDifference?.name),
);

InstallmentStageConfigsCompanion encodeContractStage(
  InstallmentContractStage stage,
  String ownerId,
  int position,
) {
  final terms = stage.terms;
  if (terms is DefermentStage) {
    return InstallmentStageConfigsCompanion.insert(
      id: stage.id,
      contractId: ownerId,
      position: position,
      stageKind: 'deferment',
      endDate: terms.until,
    );
  }
  final repayment = terms as AmortizingStage;
  final dates = repayment.dates;
  if (dates is! IntervalRepaymentDates) {
    throw ArgumentError(
      'Contract terms require interval dates; individual dates belong to schedules.',
    );
  }
  final equal = repayment.method == InstallmentRepaymentMethod.equalInstallment;
  return InstallmentStageConfigsCompanion.insert(
    id: stage.id,
    contractId: ownerId,
    position: position,
    stageKind: 'repayment',
    repaymentMethod: Value(repayment.method.name),
    intervalMonths: Value(dates.intervalMonths),
    periods: Value(dates.count),
    firstDate: Value(dates.firstDate),
    endDate: dates.getDates().last,
    accrualStartDate: Value(repayment.accrualStartDate),
    ratePeriod: Value(repayment.rate?.period.name),
    initialRatePpm: Value(repayment.rate?.ppm),
    inPeriodRepricingPolicy: Value(
      equal ? repayment.inPeriodRepricingPolicy.name : null,
    ),
    tailDifference: Value(repayment.tailDifference.name),
    accrual: Value(repayment.accrual.name),
    feeMinor: Value(repayment.fee.minorUnits),
    endPrincipalMinor: Value(repayment.endPrincipal?.minorUnits),
    amountAlgorithm: Value(
      equal
          ? switch (repayment.installmentAmount) {
              NominalRateInstallmentAmount() => 'nominalRate',
              ActualRateInstallmentAmount() => 'actualRate',
              FixedInstallmentAmount() => 'fixed',
            }
          : null,
    ),
    fixedAmountMinor: Value(
      equal && repayment.installmentAmount is FixedInstallmentAmount
          ? (repayment.installmentAmount as FixedInstallmentAmount)
                .amount
                .minorUnits
          : null,
    ),
  );
}

RateChange decodeRateChange(InstallmentRepricingRow row) => RateChange(
  resetDate: row.resetDate.toUtc(),
  effectiveDate: row.effectiveDate.toUtc(),
  spreadBp: row.spreadBp,
  referenceRate: ReferenceRate(
    date: row.referenceRateDate.toUtc(),
    type: InterestRateType.referenceTypes.byName(row.referenceRateType),
    ratePpm: row.referenceRatePpm,
    source: row.source,
  ),
);

InstallmentRepricingConfiguration decodeRepricingConfiguration(
  InstallmentRepricingConfigRow row,
) => InstallmentRepricingConfiguration(
  id: row.id,
  contractId: row.contractId,
  stageId: row.stageId,
  effectiveFrom: row.effectiveFrom.toUtc(),
  lastGeneratedDate: row.lastGeneratedDate?.toUtc(),
  rule: FloatingRateRule(
    referenceRateType: InterestRateType.referenceTypes.byName(
      row.referenceRateType,
    ),
    spreadBp: row.spreadBp,
    firstResetDate: row.firstResetDate.toUtc(),
    firstEffectiveDate: row.firstEffectiveDate.toUtc(),
    cycleMonths: row.cycleMonths,
  ),
);

InstallmentRepricingConfigsCompanion encodeRepricingConfiguration(
  InstallmentRepricingConfiguration value,
) => InstallmentRepricingConfigsCompanion.insert(
  id: value.id,
  contractId: value.contractId,
  stageId: value.stageId,
  effectiveFrom: referenceDate(value.effectiveFrom),
  referenceRateType: value.rule.referenceRateType.name,
  spreadBp: value.rule.spreadBp,
  firstResetDate: referenceDate(value.rule.firstResetDate),
  firstEffectiveDate: referenceDate(value.rule.firstEffectiveDate),
  cycleMonths: value.rule.cycleMonths,
  lastGeneratedDate: Value(
    value.lastGeneratedDate == null
        ? null
        : referenceDate(value.lastGeneratedDate!),
  ),
);

InstallmentInterestAdjustment decodeInterestAdjustment(
  InstallmentInterestAdjustmentRow row,
) => InstallmentInterestAdjustment(
  id: row.id,
  contractId: row.contractId,
  adjustment: InterestAdjustment(
    start: row.startDate.toUtc(),
    end: row.endDate.toUtc(),
    ratioPpm: row.ratioPpm,
  ),
);
