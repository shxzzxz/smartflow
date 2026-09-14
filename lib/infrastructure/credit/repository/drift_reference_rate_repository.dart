import 'package:drift/drift.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/credit/port/reference_rate_repository.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../database/app_database.dart';

class DriftReferenceRateRepository implements ReferenceRateRepository {
  DriftReferenceRateRepository(this.database);
  final AppDatabase database;

  @override
  Future<List<ReferenceRate>> read(InterestRateType type) async {
    final rows =
        await (database.select(database.referenceRates)
              ..where((r) => r.type.equals(type.name))
              ..orderBy([(r) => OrderingTerm.asc(r.rateDate)]))
            .get();
    return List.unmodifiable(
      rows.map(
        (r) => ReferenceRate(
          type: type,
          date: referenceDate(r.rateDate),
          ratePpm: r.ratePpm,
          source: r.source,
        ),
      ),
    );
  }

  @override
  Future<void> merge(InterestRateType type, List<ReferenceRate> rates) async {
    final existing = {for (final r in await read(type)) r.date: r};
    for (final rate in rates) {
      final previous = existing[rate.date];
      if (previous != null && previous.ratePpm != rate.ratePpm) {
        throw BusinessException(ReferenceRateErrorCode.conflict);
      }
      await database
          .into(database.referenceRates)
          .insert(
            ReferenceRatesCompanion.insert(
              type: type.name,
              rateDate: rate.date,
              ratePpm: rate.ratePpm,
              source: rate.source,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}
