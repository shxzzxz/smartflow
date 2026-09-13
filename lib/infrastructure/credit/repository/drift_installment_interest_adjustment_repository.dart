import 'package:drift/drift.dart';

import '../../../domain/credit/entity/installment_interest_adjustment.dart';
import '../../../domain/credit/port/installment_interest_adjustment_repository.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../database/app_database.dart';

class DriftInstallmentInterestAdjustmentRepository
    implements InstallmentInterestAdjustmentRepository {
  const DriftInstallmentInterestAdjustmentRepository(this.database);
  final AppDatabase database;

  @override
  Future<void> save(InstallmentInterestAdjustment record) async {
    final value = record.adjustment;
    await database
        .into(database.installmentInterestAdjustments)
        .insertOnConflictUpdate(
          InstallmentInterestAdjustmentsCompanion.insert(
            id: record.id,
            contractId: record.contractId,
            startDate: referenceDate(value.start),
            endDate: referenceDate(value.end),
            ratioPpm: value.ratioPpm,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> delete(String contractId, String id) async {
    await (database.delete(database.installmentInterestAdjustments)..where(
          (row) => row.id.equals(id) & row.contractId.equals(contractId),
        ))
        .go();
  }
}
