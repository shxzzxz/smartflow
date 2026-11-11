import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../domain/insurance/entity/social_insurance.dart';
import '../../../domain/insurance/port/social_insurance_repository.dart';
import '../../../domain/insurance/valobj/social_contribution_record.dart';
import '../../database/app_database.dart';

class DriftSocialInsuranceRepository implements SocialInsuranceRepository {
  const DriftSocialInsuranceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<SocialInsurance>> list({String? insuredPersonId}) async {
    final query = _database.select(_database.socialInsurances)
      ..orderBy([
        (row) => OrderingTerm(expression: row.createdAt),
        (row) => OrderingTerm(expression: row.id),
      ]);
    if (insuredPersonId != null) {
      query.where((row) => row.insuredPersonId.equals(insuredPersonId));
    }
    final rows = await query.get();
    if (rows.isEmpty) return const [];
    final ids = {for (final row in rows) row.id};
    final contributionRows =
        await (_database.select(_database.socialContributionRecords)
              ..where((row) => row.socialInsuranceId.isIn(ids))
              ..orderBy([
                (row) => OrderingTerm(expression: row.socialInsuranceId),
                (row) => OrderingTerm(expression: row.yearMonth),
              ]))
            .get();
    final contributionsByInsurance = <String, List<SocialContributionRecord>>{};
    for (final row in contributionRows) {
      contributionsByInsurance
          .putIfAbsent(row.socialInsuranceId, () => [])
          .add(
            SocialContributionRecord(
              month: MonthKey.parse(row.yearMonth),
              contributionBase: Money(minorUnits: row.contributionBaseMinor),
            ),
          );
    }
    return [
      for (final row in rows)
        SocialInsurance(
          id: row.id,
          insuredPersonId: row.insuredPersonId,
          region: row.region,
          insuranceType: row.insuranceType,
          participantType: row.participantType,
          contributionRecords: contributionsByInsurance[row.id] ?? const [],
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  @override
  Future<SocialInsurance?> find(String id) async {
    final query = _database.select(_database.socialInsurances)
      ..where((row) => row.id.equals(id));
    if (await query.getSingleOrNull() == null) return null;
    final matches = await list();
    return matches.where((insurance) => insurance.id == id).firstOrNull;
  }

  @override
  Future<void> save(SocialInsurance insurance) async {
    await _database.transaction(() async {
      await _database
          .into(_database.socialInsurances)
          .insertOnConflictUpdate(
            SocialInsurancesCompanion.insert(
              id: insurance.id,
              insuredPersonId: insurance.insuredPersonId,
              region: insurance.region,
              insuranceType: insurance.insuranceType,
              participantType: insurance.participantType,
              createdAt: Value(insurance.createdAt),
              updatedAt: Value(insurance.updatedAt),
            ),
          );
      await (_database.delete(
        _database.socialContributionRecords,
      )..where((row) => row.socialInsuranceId.equals(insurance.id))).go();
      await _database.batch((batch) {
        batch.insertAll(_database.socialContributionRecords, [
          for (final record in insurance.contributionRecords)
            SocialContributionRecordsCompanion.insert(
              socialInsuranceId: insurance.id,
              yearMonth: record.month.toString(),
              contributionBaseMinor: record.contributionBase.minorUnits,
            ),
        ]);
      });
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.socialContributionRecords,
      )..where((row) => row.socialInsuranceId.equals(id))).go();
      await (_database.delete(
        _database.socialInsurances,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<bool> existsForInsuredPerson(String insuredPersonId) async {
    final rows =
        await (_database.select(_database.socialInsurances)
              ..where((row) => row.insuredPersonId.equals(insuredPersonId))
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }
}
