import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../domain/insurance/entity/social_medical_insurance.dart';
import '../../../domain/insurance/entity/social_pension_insurance.dart';
import '../../../domain/insurance/port/social_insurance_repository.dart';
import '../../../domain/insurance/valobj/social_contribution_record.dart';
import '../../database/app_database.dart';

class DriftSocialInsuranceRepository implements SocialInsuranceRepository {
  const DriftSocialInsuranceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<SocialMedicalInsurance>> listMedical({
    String? insuredPersonId,
  }) async {
    final query = _database.select(_database.socialMedicalInsurances)
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
        await (_database.select(_database.socialMedicalContributionRecords)
              ..where((row) => row.socialMedicalInsuranceId.isIn(ids))
              ..orderBy([
                (row) => OrderingTerm(expression: row.socialMedicalInsuranceId),
                (row) => OrderingTerm(expression: row.yearMonth),
              ]))
            .get();
    final contributionsByInsurance = <String, List<SocialContributionRecord>>{};
    for (final row in contributionRows) {
      contributionsByInsurance
          .putIfAbsent(row.socialMedicalInsuranceId, () => [])
          .add(
            SocialContributionRecord(
              month: MonthKey.parse(row.yearMonth),
              contributionBase: Money(minorUnits: row.contributionBaseMinor),
            ),
          );
    }
    return [
      for (final row in rows)
        SocialMedicalInsurance(
          id: row.id,
          insuredPersonId: row.insuredPersonId,
          region: row.region,
          participantType: row.participantType,
          contributionRecords: contributionsByInsurance[row.id] ?? const [],
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  @override
  Future<SocialMedicalInsurance?> findMedical(String id) async {
    final query = _database.select(_database.socialMedicalInsurances)
      ..where((row) => row.id.equals(id));
    if (await query.getSingleOrNull() == null) return null;
    final matches = await listMedical();
    return matches.where((insurance) => insurance.id == id).firstOrNull;
  }

  @override
  Future<void> saveMedical(SocialMedicalInsurance insurance) async {
    await _database.transaction(() async {
      await _database
          .into(_database.socialMedicalInsurances)
          .insertOnConflictUpdate(
            SocialMedicalInsurancesCompanion.insert(
              id: insurance.id,
              insuredPersonId: insurance.insuredPersonId,
              region: insurance.region,
              participantType: insurance.participantType,
              createdAt: Value(insurance.createdAt),
              updatedAt: Value(insurance.updatedAt),
            ),
          );
      await (_database.delete(_database.socialMedicalContributionRecords)
            ..where((row) => row.socialMedicalInsuranceId.equals(insurance.id)))
          .go();
      await _database.batch((batch) {
        batch.insertAll(_database.socialMedicalContributionRecords, [
          for (final record in insurance.contributionRecords)
            SocialMedicalContributionRecordsCompanion.insert(
              socialMedicalInsuranceId: insurance.id,
              yearMonth: record.month.toString(),
              contributionBaseMinor: record.contributionBase.minorUnits,
            ),
        ]);
      });
    });
  }

  @override
  Future<void> deleteMedical(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.socialMedicalContributionRecords,
      )..where((row) => row.socialMedicalInsuranceId.equals(id))).go();
      await (_database.delete(
        _database.socialMedicalInsurances,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<List<SocialPensionInsurance>> listPension({
    String? insuredPersonId,
  }) async {
    final query = _database.select(_database.socialPensionInsurances)
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
        await (_database.select(_database.socialPensionContributionRecords)
              ..where((row) => row.socialPensionInsuranceId.isIn(ids))
              ..orderBy([
                (row) => OrderingTerm(expression: row.socialPensionInsuranceId),
                (row) => OrderingTerm(expression: row.yearMonth),
              ]))
            .get();
    final contributionsByInsurance = <String, List<SocialContributionRecord>>{};
    for (final row in contributionRows) {
      contributionsByInsurance
          .putIfAbsent(row.socialPensionInsuranceId, () => [])
          .add(
            SocialContributionRecord(
              month: MonthKey.parse(row.yearMonth),
              contributionBase: Money(minorUnits: row.contributionBaseMinor),
            ),
          );
    }
    return [
      for (final row in rows)
        SocialPensionInsurance(
          id: row.id,
          insuredPersonId: row.insuredPersonId,
          region: row.region,
          participantType: row.participantType,
          contributionRecords: contributionsByInsurance[row.id] ?? const [],
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  @override
  Future<SocialPensionInsurance?> findPension(String id) async {
    final query = _database.select(_database.socialPensionInsurances)
      ..where((row) => row.id.equals(id));
    if (await query.getSingleOrNull() == null) return null;
    final matches = await listPension();
    return matches.where((insurance) => insurance.id == id).firstOrNull;
  }

  @override
  Future<void> savePension(SocialPensionInsurance insurance) async {
    await _database.transaction(() async {
      await _database
          .into(_database.socialPensionInsurances)
          .insertOnConflictUpdate(
            SocialPensionInsurancesCompanion.insert(
              id: insurance.id,
              insuredPersonId: insurance.insuredPersonId,
              region: insurance.region,
              participantType: insurance.participantType,
              createdAt: Value(insurance.createdAt),
              updatedAt: Value(insurance.updatedAt),
            ),
          );
      await (_database.delete(_database.socialPensionContributionRecords)
            ..where((row) => row.socialPensionInsuranceId.equals(insurance.id)))
          .go();
      await _database.batch((batch) {
        batch.insertAll(_database.socialPensionContributionRecords, [
          for (final record in insurance.contributionRecords)
            SocialPensionContributionRecordsCompanion.insert(
              socialPensionInsuranceId: insurance.id,
              yearMonth: record.month.toString(),
              contributionBaseMinor: record.contributionBase.minorUnits,
            ),
        ]);
      });
    });
  }

  @override
  Future<void> deletePension(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.socialPensionContributionRecords,
      )..where((row) => row.socialPensionInsuranceId.equals(id))).go();
      await (_database.delete(
        _database.socialPensionInsurances,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<bool> existsForInsuredPerson(String insuredPersonId) async {
    final medical =
        await (_database.select(_database.socialMedicalInsurances)
              ..where((row) => row.insuredPersonId.equals(insuredPersonId))
              ..limit(1))
            .get();
    if (medical.isNotEmpty) return true;
    final pension =
        await (_database.select(_database.socialPensionInsurances)
              ..where((row) => row.insuredPersonId.equals(insuredPersonId))
              ..limit(1))
            .get();
    return pension.isNotEmpty;
  }
}
