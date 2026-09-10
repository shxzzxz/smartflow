import 'package:drift/drift.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/entity/installment_repricing.dart';
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
  Future<List<String>> activeContractIds() async => [
    for (final row
        in await database
            .customSelect(
              '''
      SELECT DISTINCT c.id FROM installment_contracts c
      JOIN installment_stage_configs s ON s.owner_type = 'contract' AND s.owner_id = c.id
      WHERE c.status = 'active' AND s.reference_rate_type IS NOT NULL
    ''',
              readsFrom: {
                database.installmentContracts,
                database.installmentStageConfigs,
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
  Future<void> insert(InstallmentRepricing record) async {
    final c = record.change;
    await database
        .into(database.installmentRepricingRecords)
        .insert(
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
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> update(InstallmentRepricing record) async {
    final updated =
        await (database.update(database.installmentRepricingRecords)..where(
              (r) =>
                  r.id.equals(record.id) &
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
  Future<void> discardPending(String contractId, Set<String> stageIds) async {
    if (stageIds.isEmpty) return;
    await (database.delete(database.installmentRepricingRecords)..where(
          (r) =>
              r.contractId.equals(contractId) &
              r.stageId.isIn(stageIds) &
              r.status.equals('pending'),
        ))
        .go();
  }
}
