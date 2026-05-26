import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/credit/entity/installment_contract.dart';
import '../../../domain/credit/entity/installment_repayment.dart';
import '../../../domain/credit/entity/installment_schedule.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/port/installment_repository.dart';
import '../../../domain/credit/service/installment_schedule_generator.dart';
import '../../app_database.dart';
import '../../patch_value.dart';

class DriftInstallmentRepository implements InstallmentRepository {
  DriftInstallmentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<InstallmentContract?> findContract(int id) async {
    final row =
        await (_database.select(_database.installmentContracts)
          ..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapContract(row);
  }

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    int liabilityAccountId,
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
  Future<List<InstallmentSchedule>> listSchedules(int contractId) async {
    final rows =
        await (_database.select(_database.installmentSchedules)
              ..where((s) => s.contractId.equals(contractId))
              ..orderBy([(s) => OrderingTerm.asc(s.periodNo)]))
            .get();
    return rows.map(_mapSchedule).toList();
  }

  @override
  Future<InstallmentSchedule?> findSchedule(int scheduleId) async {
    final row =
        await (_database.select(_database.installmentSchedules)
          ..where((s) => s.id.equals(scheduleId))).getSingleOrNull();
    return row == null ? null : _mapSchedule(row);
  }

  @override
  Future<List<InstallmentRepayment>> listRepayments(int contractId) async {
    final rows =
        await (_database.select(_database.installmentRepayments)
              ..where((r) => r.contractId.equals(contractId))
              ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
            .get();
    return rows.map(_mapRepayment).toList();
  }

  @override
  Future<InstallmentRepayment?> findRepaymentByTransaction(
    int transactionId,
  ) async {
    final row =
        await (_database.select(_database.installmentRepayments)..where(
          (r) => r.transactionId.equals(transactionId),
        )).getSingleOrNull();
    return row == null ? null : _mapRepayment(row);
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    int transactionId,
  ) async {
    final row =
        await (_database.select(_database.installmentContracts)..where(
          (c) => c.disbursementTransactionId.equals(transactionId),
        )).getSingleOrNull();
    return row == null ? null : _mapContract(row);
  }

  @override
  Future<int> insertContract(InstallmentContractDraft draft) {
    final now = DateTime.now();
    return _database
        .into(_database.installmentContracts)
        .insert(
          InstallmentContractsCompanion.insert(
            liabilityAccountId: draft.liabilityAccountId,
            sourceType: draft.sourceType,
            disbursementAccountId: Value(draft.disbursementAccountId),
            disbursementTransactionId: Value(draft.disbursementTransactionId),
            principalMinor: draft.principal.minorUnits,
            totalPeriods: draft.totalPeriods,
            borrowingDate: draft.borrowingDate,
            firstRepaymentDate: draft.firstRepaymentDate,
            lastRepaymentDate: draft.lastRepaymentDate,
            repaymentMethod: draft.repaymentMethod,
            interestRatePeriod: Value(draft.interestRatePeriod),
            interestRatePpm: Value(draft.interestRatePpm),
            interestAccrualMethod: Value(draft.interestAccrualMethod),
            totalFeeMinor: Value(draft.totalFeeMinor),
            status: draft.status,
            note: Value(draft.note),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> updateContract(
    int contractId,
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
    await (_database.update(_database.installmentContracts)
      ..where((c) => c.id.equals(contractId))).write(companion);
  }

  @override
  Future<void> replaceSchedules(
    int contractId,
    List<InstallmentScheduleDraft> drafts,
  ) async {
    await _database.transaction(() async {
      await (_database.delete(_database.installmentSchedules)
        ..where((s) => s.contractId.equals(contractId))).go();
      final now = DateTime.now();
      await _database.batch((batch) {
        for (final draft in drafts) {
          batch.insert(
            _database.installmentSchedules,
            InstallmentSchedulesCompanion.insert(
              contractId: contractId,
              periodNo: draft.periodNo,
              expectedRepaymentDate: draft.expectedRepaymentDate,
              expectedPrincipalMinor: Value(draft.expectedPrincipal.minorUnits),
              expectedInterestMinor: Value(draft.expectedInterest.minorUnits),
              expectedFeeMinor: Value(draft.expectedFee.minorUnits),
              status: InstallmentScheduleStatus.pending,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      });
    });
  }

  @override
  Future<void> appendSchedules(
    int contractId,
    List<InstallmentScheduleDraft> drafts,
  ) async {
    if (drafts.isEmpty) return;
    final now = DateTime.now();
    await _database.batch((batch) {
      for (final draft in drafts) {
        batch.insert(
          _database.installmentSchedules,
          InstallmentSchedulesCompanion.insert(
            contractId: contractId,
            periodNo: draft.periodNo,
            expectedRepaymentDate: draft.expectedRepaymentDate,
            expectedPrincipalMinor: Value(draft.expectedPrincipal.minorUnits),
            expectedInterestMinor: Value(draft.expectedInterest.minorUnits),
            expectedFeeMinor: Value(draft.expectedFee.minorUnits),
            status: InstallmentScheduleStatus.pending,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<void> updateSchedule(
    int scheduleId,
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
    await (_database.update(_database.installmentSchedules)
      ..where((s) => s.id.equals(scheduleId))).write(companion);
  }

  @override
  Future<int> insertRepayment(InstallmentRepaymentDraft draft) {
    final now = DateTime.now();
    return _database
        .into(_database.installmentRepayments)
        .insert(
          InstallmentRepaymentsCompanion.insert(
            contractId: draft.contractId,
            repaymentType: draft.repaymentType,
            scheduleId: Value(draft.scheduleId),
            transactionId: draft.transactionId,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> deleteRepayment(int repaymentId) async {
    await (_database.delete(_database.installmentRepayments)
      ..where((r) => r.id.equals(repaymentId))).go();
  }

  @override
  Future<void> updateContractStatus(
    int contractId,
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
  Future<void> deleteContract(int contractId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.installmentRepayments)
        ..where((r) => r.contractId.equals(contractId))).go();
      await (_database.delete(_database.installmentSchedules)
        ..where((s) => s.contractId.equals(contractId))).go();
      await (_database.delete(_database.installmentContracts)
        ..where((c) => c.id.equals(contractId))).go();
    });
  }

  InstallmentContract _mapContract(InstallmentContractRow row) {
    return InstallmentContract(
      id: row.id,
      liabilityAccountId: row.liabilityAccountId,
      sourceType: row.sourceType,
      disbursementAccountId: row.disbursementAccountId,
      disbursementTransactionId: row.disbursementTransactionId,
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

  InstallmentRepayment _mapRepayment(InstallmentRepaymentRow row) {
    return InstallmentRepayment(
      id: row.id,
      contractId: row.contractId,
      repaymentType: row.repaymentType,
      scheduleId: row.scheduleId,
      transactionId: row.transactionId,
      createdAt: row.createdAt,
    );
  }
}
