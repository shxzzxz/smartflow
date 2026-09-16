import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/credit/installment/command/installment_interest_adjustment_app_service.dart';
import 'package:smartflow/application/credit/installment/command/installment_repricing_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_operation.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';

InstallmentContractReadModel operationsContract({
  bool withRecords = false,
  bool multipleStages = false,
}) => InstallmentContractReadModel(
  id: 'loan',
  liabilityAccountId: 'account',
  sourceType: InstallmentSourceType.disbursement,
  principal: const Money(minorUnits: 10000000),
  borrowingDate: DateTime(2026, 8, 8),
  createdAt: DateTime(2026, 8, 8),
  status: InstallmentContractStatus.active,
  stageTerms: InstallmentContractTerms(
    stages: [
      InstallmentContractStage(
        id: 'stage',
        terms: AmortizingStage(
          method: InstallmentRepaymentMethod.interestFirst,
          dates: IntervalRepaymentDates(
            firstDate: DateTime(2026, 9, 8),
            count: 12,
          ),
        ),
      ),
      if (multipleStages)
        InstallmentContractStage(
          id: 'second',
          terms: AmortizingStage(
            method: InstallmentRepaymentMethod.interestFirst,
            dates: IntervalRepaymentDates(
              firstDate: DateTime(2027, 9, 8),
              count: 12,
            ),
          ),
        ),
    ],
  ),
  repricings: withRecords
      ? [
          InstallmentRepricingReadModel(
            id: 'rate',
            stageId: 'stage',
            status: InstallmentRepricingStatus.applied,
            change: RateChange(
              resetDate: DateTime(2026, 8, 20),
              effectiveDate: DateTime(2026, 8, 20),
              referenceRate: ReferenceRate(
                type: InterestRateType.lprOneYear,
                date: DateTime(2026, 8, 19),
                ratePpm: 18000,
                source: 'fixture',
              ),
              spreadBp: -10,
            ),
          ),
        ]
      : [],
  repricingConfigurations: withRecords
      ? [
          InstallmentRepricingConfigurationReadModel(
            id: 'configuration',
            stageId: 'stage',
            effectiveFrom: DateTime(2026, 8, 8),
            rule: FloatingRateRule(
              referenceRateType: InterestRateType.lprOneYear,
              spreadBp: -10,
              firstResetDate: DateTime(2026, 8, 20),
              firstEffectiveDate: DateTime(2026, 8, 20),
            ),
          ),
        ]
      : [],
  interestAdjustments: withRecords
      ? [
          InstallmentInterestAdjustmentReadModel(
            id: 'adjustment',
            adjustment: InterestAdjustment(
              start: DateTime(2026, 8, 15),
              end: DateTime(2026, 8, 25),
              ratioPpm: 500000,
            ),
          ),
        ]
      : [],
);

class RecordingRepricingService implements InstallmentRepricingAppService {
  final configurations =
      <
        ({
          String contractId,
          String stageId,
          DateTime effectiveFrom,
          FloatingRateRule rule,
        })
      >[];
  final created =
      <
        ({
          String contractId,
          String stageId,
          DateTime reset,
          DateTime effective,
          InterestRateType type,
          int bp,
        })
      >[];
  final deleted = <(String, String)>[];
  final deletedConfigurations = <(String, String)>[];
  Future<void> Function()? onWrite;

  @override
  Future<void> addConfiguration(
    String contractId, {
    required String stageId,
    required DateTime effectiveFrom,
    required FloatingRateRule rule,
  }) async {
    configurations.add((
      contractId: contractId,
      stageId: stageId,
      effectiveFrom: effectiveFrom,
      rule: rule,
    ));
    await onWrite?.call();
  }

  @override
  Future<void> create(
    String contractId, {
    required String stageId,
    required DateTime resetDate,
    required DateTime effectiveDate,
    required InterestRateType referenceRateType,
    required int spreadBp,
  }) async {
    created.add((
      contractId: contractId,
      stageId: stageId,
      reset: resetDate,
      effective: effectiveDate,
      type: referenceRateType,
      bp: spreadBp,
    ));
    await onWrite?.call();
  }

  @override
  Future<void> delete(String contractId, String recordId) async {
    deleted.add((contractId, recordId));
    await onWrite?.call();
  }

  @override
  Future<void> deleteConfiguration(
    String contractId,
    String configurationId,
  ) async {
    deletedConfigurations.add((contractId, configurationId));
    await onWrite?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingInterestAdjustments
    implements InstallmentInterestAdjustmentAppService {
  final saved =
      <({String contractId, String? id, InterestAdjustment adjustment})>[];
  final deleted = <(String, String)>[];
  Future<void> Function()? onWrite;

  @override
  Future<String> save(
    String contractId,
    InterestAdjustment adjustment, {
    String? id,
  }) async {
    saved.add((contractId: contractId, id: id, adjustment: adjustment));
    await onWrite?.call();
    return id ?? 'new-adjustment';
  }

  @override
  Future<void> delete(String contractId, String id) async {
    deleted.add((contractId, id));
    await onWrite?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
