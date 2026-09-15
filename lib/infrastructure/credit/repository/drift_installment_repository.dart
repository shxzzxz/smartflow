import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/installment_contract.dart';
import '../../../domain/credit/entity/installment_schedule.dart';
import '../../../domain/credit/entity/installment_repricing.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/port/installment_repository.dart';
import '../../database/app_database.dart';
import '../mapper/installment_stage_mapper.dart';

class DriftInstallmentRepository implements InstallmentRepository {
  DriftInstallmentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<InstallmentContract?> findContract(String id) async {
    final row = await (_database.select(
      _database.installmentContracts,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapContract(row);
  }

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final rows =
        await (_database.select(_database.installmentContracts)
              ..where((c) => c.liabilityAccountId.equals(liabilityAccountId))
              ..orderBy([
                (c) => OrderingTerm.desc(c.createdAt),
                (c) => OrderingTerm.desc(c.id),
              ]))
            .get();
    return Future.wait(rows.map(_mapContract));
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    final rows =
        await (_database.select(_database.installmentSchedules)
              ..where((s) => s.contractId.equals(contractId))
              ..orderBy([(s) => OrderingTerm.asc(s.periodNo)]))
            .get();
    return rows.map(_mapSchedule).toList();
  }

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final rows =
        await (_database.select(_database.installmentSchedules).join([
                innerJoin(
                  _database.installmentContracts,
                  _database.installmentContracts.id.equalsExp(
                    _database.installmentSchedules.contractId,
                  ),
                ),
              ])
              ..where(
                _database.installmentContracts.liabilityAccountId.equals(
                  liabilityAccountId,
                ),
              )
              ..orderBy([
                OrderingTerm.asc(
                  _database.installmentSchedules.expectedRepaymentDate,
                ),
                OrderingTerm.asc(_database.installmentSchedules.periodNo),
              ]))
            .get();
    return [
      for (final row in rows)
        _mapSchedule(row.readTable(_database.installmentSchedules)),
    ];
  }

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) async {
    final row = await (_database.select(
      _database.installmentSchedules,
    )..where((s) => s.id.equals(scheduleId))).getSingleOrNull();
    return row == null ? null : _mapSchedule(row);
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    final row =
        await (_database.select(_database.installmentContracts)
              ..where((c) => c.disbursementTransactionId.equals(transactionId)))
            .getSingleOrNull();
    return row == null ? null : _mapContract(row);
  }

  @override
  Future<void> saveContract(InstallmentContract contract) =>
      _database.transaction(() => _insertContract(contract));

  Future<void> _insertContract(InstallmentContract contract) async {
    final stageIds = {
      for (final stage in contract.stageTerms.stages)
        if (stage.terms is AmortizingStage) stage.id,
    };
    for (final config in contract.repricingConfigurations) {
      config.validate();
      if (config.contractId != contract.id ||
          !stageIds.contains(config.stageId)) {
        throw BusinessException(CreditErrorCode.contractInvalidCommand);
      }
    }
    final now = DateTime.now();
    await _database
        .into(_database.installmentContracts)
        .insert(
          InstallmentContractsCompanion.insert(
            id: contract.id,
            name: Value(contract.name),
            liabilityAccountId: contract.liabilityAccountId,
            dayCount: Value(encodeDayCount(contract.stageTerms.dayCount)),
            rounding: Value(contract.stageTerms.rounding.name),
            sourceType: contract.sourceType,
            disbursementAccountId: Value(contract.disbursementAccountId),
            disbursementTransactionId: Value(
              contract.disbursementTransactionId,
            ),
            sourceRepaymentId: Value(contract.sourceRepaymentId),
            principalMinor: contract.principal.minorUnits,

            borrowingDate: contract.borrowingDate,

            status: contract.status,
            note: Value(contract.note),
            createdAt: Value(contract.createdAt),
            updatedAt: Value(now),
          ),
        );
    await _saveStages(contract);
    for (final configuration in contract.repricingConfigurations) {
      await _database
          .into(_database.installmentRepricingConfigs)
          .insert(encodeRepricingConfiguration(configuration));
    }
  }

  Future<void> _saveStages(InstallmentContract contract) async {
    final retained = [
      for (final stage in contract.stageTerms.stages)
        if (stage.terms is AmortizingStage) stage.id,
    ];
    await (_database.delete(_database.installmentRepricingConfigs)..where(
          (row) =>
              row.contractId.equals(contract.id) &
              row.stageId.isNotIn(retained),
        ))
        .go();
    await (_database.delete(_database.installmentRepricingRecords)..where(
          (row) =>
              row.contractId.equals(contract.id) &
              row.stageId.isNotIn(retained),
        ))
        .go();
    await (_database.delete(
      _database.installmentStageConfigs,
    )..where((r) => r.contractId.equals(contract.id))).go();
    await _database.batch(
      (batch) => batch.insertAll(_database.installmentStageConfigs, [
        for (var i = 0; i < contract.stageTerms.stages.length; i++)
          encodeContractStage(contract.stageTerms.stages[i], contract.id, i),
      ]),
    );
    for (final configuration in contract.repricingConfigurations) {
      await (_database.update(_database.installmentRepricingConfigs)..where(
            (row) =>
                row.id.equals(configuration.id) &
                row.contractId.equals(contract.id),
          ))
          .write(
            InstallmentRepricingConfigsCompanion(
              generationCompleted: Value(configuration.generationCompleted),
            ),
          );
    }
  }

  @override
  Future<void> insertAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) {
    return _database.transaction(() async {
      await saveContract(contract);
      await _replaceSchedules(contract.id, schedules);
    });
  }

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) {
    return _database.transaction(() async {
      final updated =
          await (_database.update(
            _database.installmentContracts,
          )..where((row) => row.id.equals(contract.id))).write(
            InstallmentContractsCompanion(
              name: Value(contract.name),
              disbursementAccountId: Value(contract.disbursementAccountId),
              dayCount: Value(encodeDayCount(contract.stageTerms.dayCount)),
              rounding: Value(contract.stageTerms.rounding.name),

              borrowingDate: Value(contract.borrowingDate),

              status: Value(contract.status),
              note: Value(contract.note),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (updated == 0) {
        throw BusinessException(CreditErrorCode.contractPersistenceConflict);
      }
      await _saveStages(contract);
      await _replaceSchedules(contract.id, schedules);
    });
  }

  Future<void> _replaceSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  ) async {
    await (_database.delete(
      _database.installmentSchedules,
    )..where((s) => s.contractId.equals(contractId))).go();
    await _database.batch((batch) {
      for (final schedule in schedules) {
        batch.insert(_database.installmentSchedules, _scheduleInsert(schedule));
      }
    });
  }

  @override
  Future<void> deleteContract(String contractId) async {
    await (_database.delete(
      _database.installmentRepricingConfigs,
    )..where((row) => row.contractId.equals(contractId))).go();
    await (_database.delete(
      _database.installmentInterestAdjustments,
    )..where((row) => row.contractId.equals(contractId))).go();
    await (_database.delete(
      _database.installmentRepricingRecords,
    )..where((r) => r.contractId.equals(contractId))).go();
    await (_database.delete(
      _database.installmentSchedules,
    )..where((s) => s.contractId.equals(contractId))).go();
    await (_database.delete(
      _database.installmentStageConfigs,
    )..where((s) => s.contractId.equals(contractId))).go();
    await (_database.delete(
      _database.installmentContracts,
    )..where((c) => c.id.equals(contractId))).go();
  }

  InstallmentSchedulesCompanion _scheduleInsert(InstallmentSchedule schedule) {
    return InstallmentSchedulesCompanion.insert(
      id: schedule.id,
      contractId: schedule.contractId,
      stageId: Value(schedule.stageId ?? '${schedule.contractId}:stage:1'),
      periodNo: schedule.periodNo,
      expectedRepaymentDate: schedule.expectedRepaymentDate,
      expectedPrincipalMinor: Value(schedule.expectedPrincipal.minorUnits),
      expectedInterestMinor: Value(schedule.expectedInterest.minorUnits),
      expectedFeeMinor: Value(schedule.expectedFee.minorUnits),
      status: schedule.status,
      note: Value(schedule.note),
      manuallyAdjusted: Value(schedule.manuallyAdjusted),
      createdAt: Value(schedule.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

  Future<InstallmentContract> _mapContract(InstallmentContractRow row) async {
    final stages =
        await (_database.select(_database.installmentStageConfigs)
              ..where((s) => s.contractId.equals(row.id))
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();
    if (stages.isEmpty) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '合同缺少阶段配置，请检查迁移数据',
      );
    }
    return InstallmentContract(
      id: row.id,
      liabilityAccountId: row.liabilityAccountId,
      sourceType: row.sourceType,
      disbursementAccountId: row.disbursementAccountId,
      disbursementTransactionId: row.disbursementTransactionId,
      sourceRepaymentId: row.sourceRepaymentId,
      principal: Money(minorUnits: row.principalMinor),
      name: row.name,
      borrowingDate: row.borrowingDate,
      status: row.status,
      note: row.note,
      createdAt: row.createdAt,
      repricingConfigurations: [
        for (final config
            in await (_database.select(_database.installmentRepricingConfigs)
                  ..where((config) => config.contractId.equals(row.id))
                  ..orderBy([
                    (config) => OrderingTerm.asc(config.effectiveFrom),
                  ]))
                .get())
          decodeRepricingConfiguration(config),
      ],
      repricings: [
        for (final record
            in await (_database.select(_database.installmentRepricingRecords)
                  ..where((record) => record.contractId.equals(row.id))
                  ..orderBy([
                    (record) => OrderingTerm.asc(record.effectiveDate),
                  ]))
                .get())
          InstallmentRepricing(
            id: record.id,
            contractId: record.contractId,
            stageId: record.stageId,
            change: decodeRateChange(record),
            status: InstallmentRepricingStatus.values.byName(record.status),
          ),
      ],
      interestAdjustments: [
        for (final adjustment
            in await (_database.select(_database.installmentInterestAdjustments)
                  ..where((adjustment) => adjustment.contractId.equals(row.id))
                  ..orderBy([
                    (adjustment) => OrderingTerm.asc(adjustment.startDate),
                  ]))
                .get())
          decodeInterestAdjustment(adjustment),
      ],
      stageTerms: decodeContractTerms(
        stages,
        dayCount: row.dayCount,
        rounding: row.rounding,
      ),
    );
  }

  InstallmentSchedule _mapSchedule(InstallmentScheduleRow row) {
    return InstallmentSchedule(
      id: row.id,
      contractId: row.contractId,
      stageId: row.stageId,
      manuallyAdjusted: row.manuallyAdjusted,
      periodNo: row.periodNo,
      expectedRepaymentDate: row.expectedRepaymentDate,
      expectedPrincipal: Money(minorUnits: row.expectedPrincipalMinor),
      expectedInterest: Money(minorUnits: row.expectedInterestMinor),
      expectedFee: Money(minorUnits: row.expectedFeeMinor),
      status: row.status,
      note: row.note,
      createdAt: row.createdAt,
    );
  }
}
