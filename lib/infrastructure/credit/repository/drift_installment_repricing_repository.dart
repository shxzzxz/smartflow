import 'package:drift/drift.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/entity/installment_repricing.dart';
import '../../../domain/credit/entity/installment_repricing_configuration.dart';
import '../../../domain/credit/port/installment_repricing_repository.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../database/app_database.dart';
import '../mapper/installment_stage_mapper.dart';

class DriftInstallmentRepricingRepository
    implements InstallmentRepricingRepository {
  DriftInstallmentRepricingRepository(this.database);
  final AppDatabase database;
  @override
  Future<List<String>> configuredContractIds() async => [
    for (final row
        in await database
            .customSelect(
              '''
      SELECT DISTINCT c.id FROM installment_contracts c
      JOIN installment_repricing_configs r ON r.contract_id = c.id
    ''',
              readsFrom: {
                database.installmentContracts,
                database.installmentRepricingConfigs,
              },
            )
            .get())
      row.read<String>('id'),
  ];

  @override
  Future<List<InstallmentRepricing>> list(String contractId) async => [
    for (final r
        in await (database.select(database.installmentRepricingRecords)
              ..where((r) => r.contractId.equals(contractId))
              ..orderBy([
                (r) => OrderingTerm.asc(r.effectiveDate),
                (r) => OrderingTerm.asc(r.resetDate),
              ]))
            .get())
      InstallmentRepricing(
        id: r.id,
        contractId: r.contractId,
        stageId: r.stageId,
        change: decodeRateChange(r),
        status: InstallmentRepricingStatus.values.byName(r.status),
      ),
  ];

  @override
  Future<bool> insert(InstallmentRepricing record) async {
    await _requireStage(record.contractId, record.stageId);
    final c = record.change;
    final inserted = await database
        .into(database.installmentRepricingRecords)
        .insertReturningOrNull(
          InstallmentRepricingRecordsCompanion.insert(
            id: record.id,
            contractId: record.contractId,
            stageId: record.stageId,
            resetDate: referenceDate(c.resetDate),
            effectiveDate: referenceDate(c.effectiveDate),
            referenceRateDate: referenceDate(c.referenceRate.date),
            referenceRateType: c.referenceRate.type.name,
            referenceRatePpm: c.referenceRate.ratePpm,
            spreadBp: c.spreadBp,
            source: c.referenceRate.source,
          ),
          onConflict: DoNothing(
            target: [
              database.installmentRepricingRecords.contractId,
              database.installmentRepricingRecords.stageId,
              database.installmentRepricingRecords.effectiveDate,
            ],
          ),
        );
    return inserted != null;
  }

  @override
  Future<void> update(InstallmentRepricing record) async {
    final updated =
        await (database.update(database.installmentRepricingRecords)..where(
              (r) =>
                  r.id.equals(record.id) &
                  r.stageId.equals(record.stageId) &
                  r.contractId.equals(record.contractId),
            ))
            .write(
              InstallmentRepricingRecordsCompanion(
                status: Value(record.status.name),
              ),
            );
    if (updated == 0) {
      throw BusinessException(CreditErrorCode.contractPersistenceConflict);
    }
  }

  @override
  Future<void> insertConfiguration(
    InstallmentRepricingConfiguration configuration,
  ) async {
    configuration.validate();
    await _requireStage(configuration.contractId, configuration.stageId);
    final inserted = await database
        .into(database.installmentRepricingConfigs)
        .insertReturningOrNull(
          encodeRepricingConfiguration(configuration),
          onConflict: DoNothing(
            target: [
              database.installmentRepricingConfigs.contractId,
              database.installmentRepricingConfigs.stageId,
              database.installmentRepricingConfigs.effectiveFrom,
            ],
          ),
        );
    if (inserted == null) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '该阶段的配置生效日已有重定价配置',
      );
    }
  }

  @override
  Future<void> advanceGeneration(
    String configurationId,
    DateTime resetDate,
  ) async {
    final date = referenceDate(resetDate);
    await (database.update(database.installmentRepricingConfigs)..where(
          (row) =>
              row.id.equals(configurationId) &
              (row.lastGeneratedDate.isNull() |
                  row.lastGeneratedDate.isSmallerThanValue(date)),
        ))
        .write(
          InstallmentRepricingConfigsCompanion(lastGeneratedDate: Value(date)),
        );
  }

  @override
  Future<void> delete(InstallmentRepricing record) async {
    await (database.delete(database.installmentRepricingRecords)..where(
          (row) =>
              row.contractId.equals(record.contractId) &
              row.stageId.equals(record.stageId) &
              row.id.equals(record.id),
        ))
        .go();
  }

  Future<void> _requireStage(String contractId, String stageId) async {
    final stage =
        await (database.select(database.installmentStageConfigs)..where(
              (row) =>
                  row.id.equals(stageId) &
                  row.contractId.equals(contractId) &
                  row.stageKind.equals('repayment'),
            ))
            .getSingleOrNull();
    if (stage == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '重定价必须关联到本合同的还款阶段',
      );
    }
  }
}
