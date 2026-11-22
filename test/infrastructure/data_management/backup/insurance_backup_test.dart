import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_commercial_insurance_repository.dart';

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
          relationship: const Value(MemberRelationship.parent),
          gender: const Value(MemberGender.female),
          avatarPreset: const Value(MemberAvatarPreset.brother),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
        InsuredPeopleCompanion.insert(
          id: 'person-2',
          name: '张二',
          birthDate: DateTime(1995, 2, 15),
          avatarPreset: const Value(MemberAvatarPreset.sister),
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
          coverageAmountDescription: const Value('主险和附加险共享保额'),
          coverageSummary: const Value('覆盖住院医疗'),
          coverageHighlights: const Value('包含质子重离子医疗'),
          policyholderName: const Value('投保人甲'),
          beneficiaryDescription: const Value('姓名、法定或其他合同约定'),
          waitingPeriodDescription: const Value('疾病30天；意外无等待期'),
          exclusionsDescription: const Value('按承保约定处理\n特别除外约定'),
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
          description: const Value('覆盖住院和门诊医疗'),
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
          period: '2026',
          contributionAmountMinor: const Value(240000),
          note: const Value('年度补缴'),
        ),
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'medical-1',
          period: '2026-01',
          contributionBaseMinor: const Value(800000),
        ),
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'medical-1',
          period: '2026-02',
          contributionBaseMinor: const Value(820000),
        ),
        SocialContributionRecordsCompanion.insert(
          socialInsuranceId: 'pension-1',
          period: '2026-01',
          contributionBaseMinor: const Value(500000),
        ),
      ]);
    });

    final snapshot = await DriftBackupGateway(source).readSnapshot();
    expect(snapshot.rows('insured_people'), hasLength(2));
    expect(snapshot.rows('commercial_insurance_insured_people'), hasLength(2));
    expect(snapshot.rows('social_contribution_records'), hasLength(4));
    BackupService.validateSnapshot(snapshot);

    await DriftBackupGateway(target).replaceSnapshot(snapshot);
    expect(
      snapshot.rows('commercial_insurances').single,
      isNot(contains('preExistingConditionDescription')),
    );

    final people = await target.select(target.insuredPeople).get();
    expect(people, hasLength(2));
    expect(
      people.singleWhere((person) => person.id == 'person-1').avatarPreset,
      MemberAvatarPreset.brother,
    );
    expect(
      people.singleWhere((person) => person.id == 'person-2').avatarPreset,
      MemberAvatarPreset.sister,
    );
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
      hasLength(4),
    );
    final policy = await target.select(target.commercialInsurances).getSingle();
    expect(policy.coverageAmountDescription, '主险和附加险共享保额');
    expect(policy.coverageSummary, '覆盖住院医疗');
    expect(policy.coverageHighlights, '包含质子重离子医疗');
    expect(policy.policyholderName, '投保人甲');
    expect(policy.beneficiaryDescription, '姓名、法定或其他合同约定');
    expect(policy.waitingPeriodDescription, '疾病30天；意外无等待期');
    expect(policy.exclusionsDescription, '按承保约定处理\n特别除外约定');
    final repository = DriftCommercialInsuranceRepository(target);
    final restored = (await repository.find(policy.id))!;
    expect(restored.exclusionsDescription, '按承保约定处理\n特别除外约定');
    await repository.save(restored);
    final merged = await target.select(target.commercialInsurances).getSingle();
    expect(merged.exclusionsDescription, '按承保约定处理\n特别除外约定');
    expect(
      (await repository.find(policy.id))!.exclusionsDescription,
      '按承保约定处理\n特别除外约定',
    );
    final responsibility = await target
        .select(target.coverageResponsibilities)
        .getSingle();
    expect(responsibility.description, '覆盖住院和门诊医疗');
    final annual = (await target.select(target.socialContributionRecords).get())
        .singleWhere((row) => row.period == '2026');
    expect(annual.contributionBaseMinor, isNull);
    expect(annual.contributionAmountMinor, 240000);
    expect(annual.note, '年度补缴');
  });
}
