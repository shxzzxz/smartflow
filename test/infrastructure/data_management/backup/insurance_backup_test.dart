import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('round-trips every insurance table and composite identity', () async {
    final source = createTestDatabase();
    addTearDown(source.close);
    final target = createTestDatabase();
    addTearDown(target.close);
    final createdAt = DateTime(2026, 1, 1);

    await source.batch((batch) {
      batch.insertAll(source.insuredPeople, [
        InsuredPeopleCompanion.insert(
          id: 'person-1',
          name: '张一',
          birthDate: DateTime(1990, 6, 15),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
        InsuredPeopleCompanion.insert(
          id: 'person-2',
          name: '张二',
          birthDate: DateTime(1995, 2, 15),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      ]);
      batch.insertAll(source.commercialInsurances, [
        CommercialInsurancesCompanion.insert(
          id: 'commercial-1',
          name: '家庭医疗险',
          insurerName: '示例保险',
          category: CommercialInsuranceCategory.medical,
          coverageStartDate: DateTime(2025, 1, 1),
          coverageEndDate: Value(DateTime(2026, 12, 31)),
          lifetime: const Value(false),
          coverageAmountMinor: const Value(100000000),
          premiumFrequency: const Value(PremiumFrequency.annual),
          premiumAmountMinor: const Value(500000),
          premiumTermCount: const Value(20),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      ]);
      batch.insertAll(source.commercialInsuranceInsuredPeople, [
        CommercialInsuranceInsuredPeopleCompanion.insert(
          commercialInsuranceId: 'commercial-1',
          insuredPersonId: 'person-1',
        ),
        CommercialInsuranceInsuredPeopleCompanion.insert(
          commercialInsuranceId: 'commercial-1',
          insuredPersonId: 'person-2',
        ),
      ]);
      batch.insertAll(source.coverageResponsibilities, [
        CoverageResponsibilitiesCompanion.insert(
          id: 'responsibility-1',
          commercialInsuranceId: 'commercial-1',
          kind: ResponsibilityKind.medical,
          name: '医疗',
          sortOrder: 0,
        ),
      ]);
      batch.insertAll(source.responsibilityPoints, [
        ResponsibilityPointsCompanion.insert(
          id: 'point-1',
          responsibilityId: 'responsibility-1',
          label: '住院报销',
          value: '最高 100 万元',
          sortOrder: 0,
        ),
      ]);
      batch.insertAll(source.insuranceAttachments, [
        InsuranceAttachmentsCompanion.insert(
          id: 'attachment-1',
          commercialInsuranceId: 'commercial-1',
          fileName: 'contract.pdf',
          storageKey: 'attachments/contract.pdf',
          mimeType: 'application/pdf',
          createdAt: Value(createdAt),
        ),
      ]);
      batch.insertAll(source.socialInsurances, [
        SocialInsurancesCompanion.insert(
          id: 'medical-1',
          insuredPersonId: 'person-1',
          region: '上海',
          insuranceType: SocialInsuranceType.medical,
          participantType: SocialParticipantType.employee,
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
        SocialInsurancesCompanion.insert(
          id: 'pension-1',
          insuredPersonId: 'person-2',
          region: '北京',
          insuranceType: SocialInsuranceType.pension,
          participantType: SocialParticipantType.resident,
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      ]);
      batch.insertAll(source.socialContributionRecords, [
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'medical-1',
          yearMonth: '2026-01',
          contributionBaseMinor: 800000,
        ),
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'medical-1',
          yearMonth: '2026-02',
          contributionBaseMinor: 820000,
        ),
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'pension-1',
          yearMonth: '2026-01',
          contributionBaseMinor: 500000,
        ),
      ]);
    });

    final snapshot = await DriftBackupGateway(source).readSnapshot();
    expect(snapshot.rows('insured_people'), hasLength(2));
    expect(snapshot.rows('commercial_insurance_insured_people'), hasLength(2));
    expect(snapshot.rows('social_contribution_records'), hasLength(3));
    BackupService.validateSnapshot(snapshot);

    await DriftBackupGateway(target).replaceSnapshot(snapshot);

    expect(await target.select(target.insuredPeople).get(), hasLength(2));
    expect(
      await target.select(target.commercialInsurances).get(),
      hasLength(1),
    );
    expect(
      await target.select(target.commercialInsuranceInsuredPeople).get(),
      hasLength(2),
    );
    expect(
      await target.select(target.coverageResponsibilities).get(),
      hasLength(1),
    );
    expect(
      await target.select(target.responsibilityPoints).get(),
      hasLength(1),
    );
    expect(
      await target.select(target.insuranceAttachments).get(),
      hasLength(1),
    );
    expect(await target.select(target.socialInsurances).get(), hasLength(2));
    expect(
      await target.select(target.socialContributionRecords).get(),
      hasLength(3),
    );
  });
}
