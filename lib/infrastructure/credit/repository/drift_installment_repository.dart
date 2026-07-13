import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/installment_contract.dart';
import '../../../domain/credit/entity/installment_schedule.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/port/installment_repository.dart';
import '../../database/app_database.dart';

class DriftInstallmentRepository implements InstallmentRepository {
  DriftInstallmentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<InstallmentContract?> findContract(String id) async {
    final row =
        await (_database.select(_database.installmentContracts)
          ..where((c) => c.id.equals(id))).getSingleOrNull();
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
    return rows.map(_mapContract).toList();
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
    final row =
        await (_database.select(_database.installmentSchedules)
          ..where((s) => s.id.equals(scheduleId))).getSingleOrNull();
    return row == null ? null : _mapSchedule(row);
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    final row =
        await (_database.select(_database.installmentContracts)..where(
          (c) => c.disbursementTransactionId.equals(transactionId),
        )).getSingleOrNull();
    return row == null ? null : _mapContract(row);
  }

  @override
  Future<void> saveContract(InstallmentContract contract) async {
    final now = DateTime.now();
    await _database
        .into(_database.installmentContracts)
        .insert(
          InstallmentContractsCompanion.insert(
            id: contract.id,
            liabilityAccountId: contract.liabilityAccountId,
            sourceType: contract.sourceType,
            disbursementAccountId: Value(contract.disbursementAccountId),
            disbursementTransactionId: Value(
              contract.disbursementTransactionId,
            ),
            sourceRepaymentId: Value(contract.sourceRepaymentId),
            principalMinor: contract.principal.minorUnits,
            totalPeriods: contract.totalPeriods,
            borrowingDate: contract.borrowingDate,
            firstRepaymentDate: contract.firstRepaymentDate,
            lastRepaymentDate: contract.lastRepaymentDate,
            repaymentMethod: contract.repaymentMethod,
            interestRatePeriod: Value(contract.interestRatePeriod),
            interestRatePpm: Value(contract.interestRatePpm),
            interestAccrualMethod: Value(contract.interestAccrualMethod),
            totalFeeMinor: Value(contract.totalFeeMinor),
            status: contract.status,
            note: Value(contract.note),
            createdAt: Value(contract.createdAt),
            updatedAt: Value(now),
          ),
        );
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
      final updated = await (_database.update(_database.installmentContracts)
        ..where((row) => row.id.equals(contract.id))).write(
        InstallmentContractsCompanion(
          disbursementAccountId: Value(contract.disbursementAccountId),
          totalPeriods: Value(contract.totalPeriods),
          borrowingDate: Value(contract.borrowingDate),
          firstRepaymentDate: Value(contract.firstRepaymentDate),
          lastRepaymentDate: Value(contract.lastRepaymentDate),
          repaymentMethod: Value(contract.repaymentMethod),
          interestRatePeriod: Value(contract.interestRatePeriod),
          interestRatePpm: Value(contract.interestRatePpm),
          interestAccrualMethod: Value(contract.interestAccrualMethod),
          totalFeeMinor: Value(contract.totalFeeMinor),
          status: Value(contract.status),
          note: Value(contract.note),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (updated == 0) {
        throw BusinessException(CreditErrorCode.contractPersistenceConflict);
      }
      await _replaceSchedules(contract.id, schedules);
    });
  }

  Future<void> _replaceSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  ) async {
    await (_database.delete(_database.installmentSchedules)
      ..where((s) => s.contractId.equals(contractId))).go();
    await _database.batch((batch) {
      for (final schedule in schedules) {
        batch.insert(_database.installmentSchedules, _scheduleInsert(schedule));
      }
    });
  }

  @override
  Future<void> deleteContract(String contractId) async {
    await (_database.delete(_database.installmentSchedules)
      ..where((s) => s.contractId.equals(contractId))).go();
    await (_database.delete(_database.installmentContracts)
      ..where((c) => c.id.equals(contractId))).go();
  }

  InstallmentSchedulesCompanion _scheduleInsert(InstallmentSchedule schedule) {
    return InstallmentSchedulesCompanion.insert(
      id: schedule.id,
      contractId: schedule.contractId,
      periodNo: schedule.periodNo,
      expectedRepaymentDate: schedule.expectedRepaymentDate,
      expectedPrincipalMinor: Value(schedule.expectedPrincipal.minorUnits),
      expectedInterestMinor: Value(schedule.expectedInterest.minorUnits),
      expectedFeeMinor: Value(schedule.expectedFee.minorUnits),
      status: schedule.status,
      note: Value(schedule.note),
      createdAt: Value(schedule.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

  InstallmentContract _mapContract(InstallmentContractRow row) {
    return InstallmentContract(
      id: row.id,
      liabilityAccountId: row.liabilityAccountId,
      sourceType: row.sourceType,
      disbursementAccountId: row.disbursementAccountId,
      disbursementTransactionId: row.disbursementTransactionId,
      sourceRepaymentId: row.sourceRepaymentId,
      principal: Money(minorUnits: row.principalMinor),
      totalPeriods: row.totalPeriods,
      borrowingDate: row.borrowingDate,
      firstRepaymentDate: row.firstRepaymentDate,
      lastRepaymentDate: row.lastRepaymentDate,
      repaymentMethod: row.repaymentMethod,
      interestRatePeriod: row.interestRatePeriod,
      interestRatePpm: row.interestRatePpm,
      interestAccrualMethod: row.interestAccrualMethod,
      totalFeeMinor: row.totalFeeMinor,
      status: row.status,
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  InstallmentSchedule _mapSchedule(InstallmentScheduleRow row) {
    return InstallmentSchedule(
      id: row.id,
      contractId: row.contractId,
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
