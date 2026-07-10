import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/installment_contract.dart';
import '../../../domain/credit/entity/installment_schedule.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/port/installment_repository.dart';
import '../../database/app_database.dart';
import '../../database/patch_value.dart';

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
  Future<void> updateContract(
    String contractId,
    InstallmentContractPatch patch,
  ) async {
    final companion = InstallmentContractsCompanion(
      totalPeriods:
          patch.totalPeriods == null
              ? const Value.absent()
              : Value(patch.totalPeriods!),
      firstRepaymentDate:
          patch.firstRepaymentDate == null
              ? const Value.absent()
              : Value(patch.firstRepaymentDate!),
      lastRepaymentDate:
          patch.lastRepaymentDate == null
              ? const Value.absent()
              : Value(patch.lastRepaymentDate!),
      borrowingDate:
          patch.borrowingDate == null
              ? const Value.absent()
              : Value(patch.borrowingDate!),
      repaymentMethod:
          patch.repaymentMethod == null
              ? const Value.absent()
              : Value(patch.repaymentMethod!),
      interestRatePeriod: patch.interestRatePeriod.toValue(),
      interestRatePpm: patch.interestRatePpm.toValue(),
      interestAccrualMethod:
          patch.interestAccrualMethod == null
              ? const Value.absent()
              : Value(patch.interestAccrualMethod!),
      totalFeeMinor:
          patch.totalFeeMinor == null
              ? const Value.absent()
              : Value(patch.totalFeeMinor!),
      note: patch.note.toValue(),
      disbursementAccountId:
          patch.disbursementAccountId == null
              ? const Value.absent()
              : Value(patch.disbursementAccountId!),
      updatedAt: Value(DateTime.now()),
    );
    final updated = await (_database.update(_database.installmentContracts)
      ..where((c) => c.id.equals(contractId))).write(companion);
    if (updated == 0) {
      throw BusinessException(CreditErrorCode.contractPersistenceConflict);
    }
  }

  @override
  Future<void> replaceSchedules(
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
  Future<void> appendSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  ) async {
    if (schedules.isEmpty) return;
    await _database.batch((batch) {
      for (final schedule in schedules) {
        batch.insert(_database.installmentSchedules, _scheduleInsert(schedule));
      }
    });
  }

  @override
  Future<void> updateSchedule(
    String scheduleId,
    InstallmentSchedulePatch patch,
  ) async {
    final companion = InstallmentSchedulesCompanion(
      expectedRepaymentDate:
          patch.expectedRepaymentDate == null
              ? const Value.absent()
              : Value(patch.expectedRepaymentDate!),
      expectedPrincipalMinor:
          patch.expectedPrincipal == null
              ? const Value.absent()
              : Value(patch.expectedPrincipal!.minorUnits),
      expectedInterestMinor:
          patch.expectedInterest == null
              ? const Value.absent()
              : Value(patch.expectedInterest!.minorUnits),
      expectedFeeMinor:
          patch.expectedFee == null
              ? const Value.absent()
              : Value(patch.expectedFee!.minorUnits),
      status:
          patch.status == null ? const Value.absent() : Value(patch.status!),
      note: patch.note.toValue(),
      updatedAt: Value(DateTime.now()),
    );
    final updated = await (_database.update(_database.installmentSchedules)
      ..where((s) => s.id.equals(scheduleId))).write(companion);
    if (updated == 0) {
      throw BusinessException(CreditErrorCode.contractPersistenceConflict);
    }
  }

  @override
  Future<void> updateContractStatus(
    String contractId,
    InstallmentContractStatus status,
  ) async {
    await (_database.update(_database.installmentContracts)
      ..where((c) => c.id.equals(contractId))).write(
      InstallmentContractsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
