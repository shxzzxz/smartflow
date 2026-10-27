import 'package:drift/drift.dart';

import '../../../domain/orchestration/entity/advance_case.dart';
import '../../../domain/orchestration/port/advance_case_repository.dart';
import '../../../domain/orchestration/valobj/advance_enums.dart';
import '../../database/app_database.dart';

class DriftAdvanceCaseRepository implements AdvanceCaseRepository {
  const DriftAdvanceCaseRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AdvanceCase?> findById(String id) async {
    final row = await (_database.select(
      _database.advanceCases,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<AdvanceCase?> findAccountCase({
    required String receivableAccountId,
    required AdvanceScenario scenario,
  }) async {
    final row =
        await (_database.select(_database.advanceCases)..where(
              (table) =>
                  table.trackingMode.equalsValue(AdvanceTrackingMode.account) &
                  table.receivableAccountId.equals(receivableAccountId) &
                  table.scenario.equalsValue(scenario),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(AdvanceCase advanceCase) async {
    advanceCase.validate();
    await _database
        .into(_database.advanceCases)
        .insertOnConflictUpdate(
          AdvanceCasesCompanion.insert(
            id: advanceCase.id,
            scenario: advanceCase.scenario,
            trackingMode: advanceCase.trackingMode,
            receivableAccountId: Value(advanceCase.receivableAccountId),
            aaPeopleCount: Value(advanceCase.aaPeopleCount),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  AdvanceCase _toDomain(AdvanceCaseRow row) {
    return AdvanceCase(
      id: row.id,
      scenario: row.scenario,
      trackingMode: row.trackingMode,
      receivableAccountId: row.receivableAccountId,
      aaPeopleCount: row.aaPeopleCount,
    );
  }
}
