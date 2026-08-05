import 'package:drift/drift.dart';

import '../../../domain/credit/port/bill_generation_suppression_repository.dart';
import '../../../domain/credit/valobj/bill_period.dart';
import '../../database/app_database.dart';

class DriftBillGenerationSuppressionRepository
    implements BillGenerationSuppressionRepository {
  DriftBillGenerationSuppressionRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> clear(String accountId, BillPeriod period) async {
    await (_database.delete(_database.billGenerationSuppressions)..where(
      (row) =>
          row.accountId.equals(accountId) & row.period.equals(period.toInt()),
    )).go();
  }

  @override
  Future<void> clearAll(String accountId) async {
    await (_database.delete(_database.billGenerationSuppressions)
      ..where((row) => row.accountId.equals(accountId))).go();
  }

  @override
  Future<bool> isSuppressed(String accountId, BillPeriod period) async {
    final row =
        await (_database.select(_database.billGenerationSuppressions)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.period.equals(period.toInt()),
        )).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> suppress(String accountId, BillPeriod period) {
    return _database
        .into(_database.billGenerationSuppressions)
        .insert(
          BillGenerationSuppressionsCompanion.insert(
            accountId: accountId,
            period: period.toInt(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
