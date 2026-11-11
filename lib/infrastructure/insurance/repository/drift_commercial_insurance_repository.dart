import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/insurance/entity/commercial_insurance.dart';
import '../../../domain/insurance/port/commercial_insurance_repository.dart';
import '../../../domain/insurance/valobj/coverage_amount.dart';
import '../../../domain/insurance/valobj/coverage_responsibility.dart';
import '../../../domain/insurance/valobj/coverage_term.dart';
import '../../../domain/insurance/valobj/insurance_attachment.dart';
import '../../../domain/insurance/valobj/premium_plan.dart';
import '../../database/app_database.dart';

class DriftCommercialInsuranceRepository
    implements CommercialInsuranceRepository {
  const DriftCommercialInsuranceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<CommercialInsurance>> list({String? insuredPersonId}) async {
    Set<String>? insuranceIds;
    if (insuredPersonId != null) {
      final links = await (_database.select(
        _database.commercialInsuranceInsuredPeople,
      )..where((row) => row.insuredPersonId.equals(insuredPersonId))).get();
      insuranceIds = {for (final link in links) link.commercialInsuranceId};
      if (insuranceIds.isEmpty) return const [];
    }

    final query = _database.select(_database.commercialInsurances)
      ..orderBy([
        (row) => OrderingTerm(expression: row.createdAt),
        (row) => OrderingTerm(expression: row.id),
      ]);
    if (insuranceIds != null) {
      query.where((row) => row.id.isIn(insuranceIds!));
    }
    return _hydrate(await query.get());
  }

  @override
  Future<CommercialInsurance?> find(String id) async {
    final query = _database.select(_database.commercialInsurances)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  @override
  Future<bool> existsForInsuredPerson(String insuredPersonId) async {
    final query = _database.select(_database.commercialInsuranceInsuredPeople)
      ..where((row) => row.insuredPersonId.equals(insuredPersonId))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  @override
  Future<void> save(CommercialInsurance insurance) async {
    await _database.transaction(() async {
      await _database
          .into(_database.commercialInsurances)
          .insertOnConflictUpdate(
            CommercialInsurancesCompanion.insert(
              id: insurance.id,
              name: insurance.name,
              insurerName: insurance.insurerName,
              category: insurance.category,
              productForm: Value(insurance.productForm),
              coverageStartDate: insurance.coverageTerm.startDate,
              coverageEndDate: Value(insurance.coverageTerm.endDate),
              lifetime: Value(insurance.coverageTerm.lifetime),
              coverageAmountMinor: Value(
                insurance.coverageAmount?.amount?.minorUnits,
              ),
              premiumAmountMinor: Value(
                insurance.premiumPlan?.amount?.minorUnits,
              ),
              premiumFrequency: Value(insurance.premiumPlan?.frequency),
              premiumTermCount: Value(insurance.premiumPlan?.termCount),
              createdAt: Value(insurance.createdAt),
              updatedAt: Value(insurance.updatedAt),
            ),
          );

      await _deleteChildren(insurance.id);

      await _database.batch((batch) {
        batch.insertAll(_database.commercialInsuranceInsuredPeople, [
          for (final personId in insurance.insuredPersonIds)
            CommercialInsuranceInsuredPeopleCompanion.insert(
              commercialInsuranceId: insurance.id,
              insuredPersonId: personId,
            ),
        ]);
        batch.insertAll(_database.coverageResponsibilities, [
          for (final responsibility in insurance.responsibilities)
            CoverageResponsibilitiesCompanion.insert(
              id: responsibility.id,
              commercialInsuranceId: insurance.id,
              kind: responsibility.kind,
              name: responsibility.name,
              sortOrder: responsibility.order,
            ),
        ]);
        batch.insertAll(_database.responsibilityPoints, [
          for (final responsibility in insurance.responsibilities)
            for (final point in responsibility.points)
              ResponsibilityPointsCompanion.insert(
                id: point.id,
                responsibilityId: responsibility.id,
                label: point.label.trim(),
                value: point.value.trim(),
                sortOrder: point.order,
              ),
        ]);
        batch.insertAll(_database.insuranceAttachments, [
          for (final attachment in insurance.attachments)
            InsuranceAttachmentsCompanion.insert(
              id: attachment.id,
              commercialInsuranceId: insurance.id,
              fileName: attachment.fileName,
              storageKey: attachment.storageKey,
              mimeType: attachment.mimeType,
              createdAt: Value(attachment.createdAt),
            ),
        ]);
      });
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      await _deleteChildren(id);
      await (_database.delete(
        _database.commercialInsurances,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  Future<void> _deleteChildren(String insuranceId) async {
    final responsibilityRows = await (_database.select(
      _database.coverageResponsibilities,
    )..where((row) => row.commercialInsuranceId.equals(insuranceId))).get();
    final responsibilityIds = {for (final row in responsibilityRows) row.id};
    if (responsibilityIds.isNotEmpty) {
      await (_database.delete(
        _database.responsibilityPoints,
      )..where((row) => row.responsibilityId.isIn(responsibilityIds))).go();
    }
    await (_database.delete(
      _database.coverageResponsibilities,
    )..where((row) => row.commercialInsuranceId.equals(insuranceId))).go();
    await (_database.delete(
      _database.commercialInsuranceInsuredPeople,
    )..where((row) => row.commercialInsuranceId.equals(insuranceId))).go();
    await (_database.delete(
      _database.insuranceAttachments,
    )..where((row) => row.commercialInsuranceId.equals(insuranceId))).go();
  }

  Future<List<CommercialInsurance>> _hydrate(
    List<CommercialInsuranceRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final insuranceIds = {for (final row in rows) row.id};

    final links = await (_database.select(
      _database.commercialInsuranceInsuredPeople,
    )..where((row) => row.commercialInsuranceId.isIn(insuranceIds))).get();
    final responsibilityRows =
        await (_database.select(_database.coverageResponsibilities)
              ..where((row) => row.commercialInsuranceId.isIn(insuranceIds))
              ..orderBy([
                (row) => OrderingTerm(expression: row.commercialInsuranceId),
                (row) => OrderingTerm(expression: row.sortOrder),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    final responsibilityIds = {for (final row in responsibilityRows) row.id};
    final pointRows = responsibilityIds.isEmpty
        ? const <ResponsibilityPointRow>[]
        : await (_database.select(_database.responsibilityPoints)
                ..where((row) => row.responsibilityId.isIn(responsibilityIds))
                ..orderBy([
                  (row) => OrderingTerm(expression: row.responsibilityId),
                  (row) => OrderingTerm(expression: row.sortOrder),
                  (row) => OrderingTerm(expression: row.id),
                ]))
              .get();
    final attachmentRows =
        await (_database.select(_database.insuranceAttachments)
              ..where((row) => row.commercialInsuranceId.isIn(insuranceIds))
              ..orderBy([
                (row) => OrderingTerm(expression: row.createdAt),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();

    final linksByInsurance = <String, List<String>>{};
    for (final link in links) {
      linksByInsurance
          .putIfAbsent(link.commercialInsuranceId, () => [])
          .add(link.insuredPersonId);
    }
    final pointsByResponsibility = <String, List<ResponsibilityPoint>>{};
    for (final point in pointRows) {
      pointsByResponsibility
          .putIfAbsent(point.responsibilityId, () => [])
          .add(
            ResponsibilityPoint(
              id: point.id,
              label: point.label,
              value: point.value,
              order: point.sortOrder,
            ),
          );
    }
    final responsibilitiesByInsurance =
        <String, List<CoverageResponsibility>>{};
    for (final row in responsibilityRows) {
      responsibilitiesByInsurance
          .putIfAbsent(row.commercialInsuranceId, () => [])
          .add(
            CoverageResponsibility(
              id: row.id,
              kind: row.kind,
              name: row.name,
              points: pointsByResponsibility[row.id] ?? const [],
              order: row.sortOrder,
            ),
          );
    }
    final attachmentsByInsurance = <String, List<InsuranceAttachment>>{};
    for (final row in attachmentRows) {
      attachmentsByInsurance
          .putIfAbsent(row.commercialInsuranceId, () => [])
          .add(
            InsuranceAttachment(
              id: row.id,
              fileName: row.fileName,
              storageKey: row.storageKey,
              mimeType: row.mimeType,
              createdAt: row.createdAt,
            ),
          );
    }

    return [
      for (final row in rows)
        CommercialInsurance(
          id: row.id,
          name: row.name,
          insurerName: row.insurerName,
          category: row.category,
          productForm: row.productForm,
          coverageTerm: CoverageTerm(
            startDate: row.coverageStartDate,
            endDate: row.coverageEndDate,
            lifetime: row.lifetime,
          ),
          coverageAmount: row.coverageAmountMinor == null
              ? null
              : CoverageAmount(
                  amount: row.coverageAmountMinor == null
                      ? null
                      : Money(minorUnits: row.coverageAmountMinor!),
                ),
          premiumPlan: row.premiumFrequency == null
              ? null
              : PremiumPlan(
                  amount: row.premiumAmountMinor == null
                      ? null
                      : Money(minorUnits: row.premiumAmountMinor!),
                  frequency: row.premiumFrequency!,
                  termCount: row.premiumTermCount,
                ),
          insuredPersonIds: linksByInsurance[row.id] ?? const [],
          responsibilities: responsibilitiesByInsurance[row.id] ?? const [],
          attachments: attachmentsByInsurance[row.id] ?? const [],
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
    ];
  }
}
