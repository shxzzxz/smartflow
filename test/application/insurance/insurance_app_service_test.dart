import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/application/insurance/attachment/port/insurance_attachment_storage.dart';
import 'package:smartflow/application/insurance/commercial_insurance/command/commercial_insurance_app_service.dart';
import 'package:smartflow/application/insurance/commercial_insurance/command/commercial_insurance_command.dart';
import 'package:smartflow/application/insurance/coverage_overview/query/insurance_coverage_query_service.dart';
import 'package:smartflow/application/insurance/insured_person/command/insured_person_app_service.dart';
import 'package:smartflow/application/insurance/insured_person/command/insured_person_command.dart';
import 'package:smartflow/application/insurance/social_insurance/command/social_insurance_app_service.dart';
import 'package:smartflow/application/insurance/social_insurance/command/social_insurance_command.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_amount.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_term.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_error_code.dart';
import 'package:smartflow/domain/insurance/valobj/premium_plan.dart';
import 'package:smartflow/domain/insurance/valobj/social_contribution_record.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_commercial_insurance_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_insured_person_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_social_insurance_repository.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;
  late DriftInsuredPersonRepository insuredPeople;
  late DriftCommercialInsuranceRepository commercialInsurances;
  late DriftSocialInsuranceRepository socialInsurances;
  late SequentialIdGenerator ids;
  late _MemoryAttachmentStorage attachmentStorage;
  late InsuredPersonAppServiceImpl insuredPersonService;
  late CommercialInsuranceAppServiceImpl commercialService;
  late SocialInsuranceAppServiceImpl socialService;
  late InsuranceCoverageQueryServiceImpl queryService;

  setUp(() {
    database = createTestDatabase();
    insuredPeople = DriftInsuredPersonRepository(database);
    commercialInsurances = DriftCommercialInsuranceRepository(database);
    socialInsurances = DriftSocialInsuranceRepository(database);
    ids = SequentialIdGenerator(prefix: 'test');
    attachmentStorage = _MemoryAttachmentStorage();
    final runner = DriftTransactionRunner(database);
    insuredPersonService = InsuredPersonAppServiceImpl(
      insuredPeople: insuredPeople,
      commercialInsurances: commercialInsurances,
      socialInsurances: socialInsurances,
      runner: runner,
      ids: ids,
      now: () => DateTime(2026, 1, 1),
    );
    commercialService = CommercialInsuranceAppServiceImpl(
      insurances: commercialInsurances,
      insuredPeople: insuredPeople,
      attachmentStorage: attachmentStorage,
      runner: runner,
      ids: ids,
      now: () => DateTime(2026, 1, 1),
    );
    socialService = SocialInsuranceAppServiceImpl(
      insurances: socialInsurances,
      insuredPeople: insuredPeople,
      runner: runner,
      ids: ids,
      now: () => DateTime(2026, 1, 1),
    );
    queryService = InsuranceCoverageQueryServiceImpl(
      insuredPeople: insuredPeople,
      commercialInsurances: commercialInsurances,
      socialInsurances: socialInsurances,
      now: () => DateTime(2026, 1, 1),
    );
  });

  tearDown(() => database.close());

  test(
    'multi-member commercial insurance is visible to every member',
    () async {
      final first = await _savePerson(insuredPersonService, '张一');
      final second = await _savePerson(insuredPersonService, '张二');
      final insuranceId = await commercialService.save(
        SaveCommercialInsuranceCommand(
          name: '家庭医疗险',
          insurerName: '示例保险',
          category: CommercialInsuranceCategory.medical,
          coverageTerm: CoverageTerm(
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2026, 12, 31),
          ),
          insuredPersonIds: [first, second],
          responsibilities: const [
            InsuranceResponsibilityInput(
              kind: ResponsibilityKind.medical,
              name: '一般医疗',
              points: [
                InsuranceResponsibilityPointInput(
                  label: '住院报销',
                  value: '最高 100 万元',
                ),
              ],
            ),
          ],
        ),
      );

      final members = await queryService.listMembers();
      expect(members.map((member) => member.commercialInsuranceCount), [1, 1]);
      expect(
        (await queryService.memberCoverage(
          first,
        ))!.commercialInsurances.single.id,
        insuranceId,
      );
      expect(
        (await queryService.memberCoverage(
          second,
        ))!.commercialInsurances.single.id,
        insuranceId,
      );
      final detail = await queryService.commercialInsuranceDetail(insuranceId);
      expect(detail!.insuredPeople.map((person) => person.id), [first, second]);

      await expectLater(
        insuredPersonService.delete(first),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            InsuranceErrorCode.insuredPersonInUse.code,
          ),
        ),
      );
    },
  );

  test(
    'saves benefit types and can clear a responsibility description',
    () async {
      final person = await _savePerson(insuredPersonService, '示例成员');
      final insuranceId = await commercialService.save(
        _commercialCommand(
          [person],
          responsibilities: const [
            InsuranceResponsibilityInput(
              kind: ResponsibilityKind.diseaseBenefit,
              name: '重大疾病',
              description: '  达到合同约定条件后给付保险金  ',
              points: [
                InsuranceResponsibilityPointInput(label: '赔付比例', value: '100%'),
              ],
            ),
            InsuranceResponsibilityInput(
              kind: ResponsibilityKind.death,
              name: '意外身故',
              description: '意外事故导致身故',
              points: [],
            ),
          ],
        ),
      );
      final original = (await commercialInsurances.find(insuranceId))!;
      expect(original.responsibilities.map((item) => item.kind), [
        ResponsibilityKind.diseaseBenefit,
        ResponsibilityKind.death,
      ]);
      expect(original.responsibilities.first.description, '达到合同约定条件后给付保险金');

      await commercialService.save(
        _commercialCommand(
          [person],
          id: insuranceId,
          responsibilities: [
            InsuranceResponsibilityInput(
              id: original.responsibilities.first.id,
              kind: ResponsibilityKind.diseaseBenefit,
              name: '重大疾病',
              description: '  ',
              points: [
                InsuranceResponsibilityPointInput(
                  id: original.responsibilities.first.points.single.id,
                  label: '赔付比例',
                  value: '100%',
                ),
              ],
            ),
            InsuranceResponsibilityInput(
              id: original.responsibilities.last.id,
              kind: ResponsibilityKind.death,
              name: '意外身故',
              description: '意外事故导致身故',
              points: const [],
            ),
          ],
        ),
      );
      final saved = (await queryService.commercialInsuranceDetail(
        insuranceId,
      ))!.insurance;
      expect(saved.responsibilities.first.description, isNull);
      expect(saved.responsibilities.last.description, '意外事故导致身故');
      expect(
        saved.responsibilities.map((item) => item.id),
        original.responsibilities.map((item) => item.id),
      );
      expect(
        saved.responsibilities.first.points.single.id,
        original.responsibilities.first.points.single.id,
      );
    },
  );

  test(
    'contract text survives other saves and attachments and can be cleared',
    () async {
      final person = await _savePerson(insuredPersonService, '示例成员');
      final insuranceId = await commercialService.save(
        SaveCommercialInsuranceCommand(
          name: '合同信息记录',
          insurerName: '示例保险',
          category: CommercialInsuranceCategory.medical,
          coverageTerm: CoverageTerm(startDate: DateTime(2025, 1, 1)),
          insuredPersonIds: [person],
          policyholderName: '  示例公司  ',
          beneficiaryDescription: '  法定或其他合同约定  ',
          waitingPeriodDescription: '  疾病30天；意外无等待期  ',
          exclusionsDescription: '  以本保单承保约定为准\n指定疾病相关责任除外  ',
          responsibilities: const [
            InsuranceResponsibilityInput(
              kind: ResponsibilityKind.medical,
              name: '一般医疗',
              points: [
                InsuranceResponsibilityPointInput(
                  label: '等待期',
                  value: '特别约定15天',
                ),
              ],
            ),
          ],
        ),
      );
      final original = (await commercialInsurances.find(insuranceId))!;
      expect(
        [
          original.policyholderName,
          original.beneficiaryDescription,
          original.waitingPeriodDescription,
          original.exclusionsDescription,
        ],
        ['示例公司', '法定或其他合同约定', '疾病30天；意外无等待期', '以本保单承保约定为准\n指定疾病相关责任除外'],
      );
      SaveCommercialInsuranceCommand update({
        String? policyholderName,
        String? beneficiaryDescription,
        String? waitingPeriodDescription,
        String? exclusionsDescription,
      }) => SaveCommercialInsuranceCommand(
        id: insuranceId,
        name: original.name,
        insurerName: original.insurerName,
        category: original.category,
        coverageTerm: original.coverageTerm,
        insuredPersonIds: original.insuredPersonIds,
        policyholderName: policyholderName,
        beneficiaryDescription: beneficiaryDescription,
        waitingPeriodDescription: waitingPeriodDescription,
        exclusionsDescription: exclusionsDescription,
      );
      await commercialService.save(update());
      await commercialService.addAttachments(insuranceId);
      var saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.policyholderName, '示例公司');
      expect(saved.beneficiaryDescription, '法定或其他合同约定');
      expect(saved.waitingPeriodDescription, '疾病30天；意外无等待期');
      expect(saved.exclusionsDescription, '以本保单承保约定为准\n指定疾病相关责任除外');
      await commercialService.save(update(beneficiaryDescription: '  '));
      saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.beneficiaryDescription, isNull);
      expect(saved.policyholderName, '示例公司');
      expect(saved.exclusionsDescription, '以本保单承保约定为准\n指定疾病相关责任除外');
      await commercialService.save(
        update(
          policyholderName: '',
          waitingPeriodDescription: '',
          exclusionsDescription: '',
        ),
      );
      saved = (await commercialInsurances.find(insuranceId))!;
      expect([
        saved.policyholderName,
        saved.beneficiaryDescription,
        saved.waitingPeriodDescription,
        saved.exclusionsDescription,
      ], everyElement(isNull));
      expect(
        saved.responsibilities.single.id,
        original.responsibilities.single.id,
      );
      expect(saved.responsibilities.single.points.single.value, '特别约定15天');
      expect(saved.attachments, hasLength(1));
    },
  );

  test(
    'exclusions survive basic edits and can be replaced or cleared',
    () async {
      final person = await _savePerson(insuredPersonService, '示例成员');
      final id = await commercialService.save(_commercialCommand([person]));
      final original = (await commercialInsurances.find(id))!;
      SaveCommercialInsuranceCommand update({String? exclusions}) =>
          SaveCommercialInsuranceCommand(
            id: id,
            name: original.name,
            insurerName: original.insurerName,
            category: original.category,
            coverageTerm: original.coverageTerm,
            insuredPersonIds: original.insuredPersonIds,
            exclusionsDescription: exclusions,
          );
      await commercialService.save(update(exclusions: '既往症相关承保约定\n指定疾病除外'));
      await commercialService.save(update());
      var row = await (database.select(
        database.commercialInsurances,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.exclusionsDescription, '既往症相关承保约定\n指定疾病除外');
      await commercialService.save(update(exclusions: '新的除外约定'));
      expect(
        (await commercialInsurances.find(id))!.exclusionsDescription,
        '新的除外约定',
      );
      await commercialService.save(update(exclusions: ''));
      row = await (database.select(
        database.commercialInsurances,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.exclusionsDescription, isNull);
      expect(
        (await commercialInsurances.find(id))!.exclusionsDescription,
        isNull,
      );
    },
  );

  test(
    'payment configuration survives other edits and clears independently',
    () async {
      final person = await _savePerson(insuredPersonService, '示例成员');
      final insuranceId = await commercialService.save(
        _commercialCommand([person]),
      );
      await commercialService.addAttachments(insuranceId);
      final original = (await commercialInsurances.find(insuranceId))!;
      const plan = PremiumPlan(
        frequency: PremiumFrequency.annual,
        termCount: 20,
        amount: Money(minorUnits: 120000),
      );
      await commercialService.updatePremiumPlan(
        insuranceId: insuranceId,
        premiumPlan: plan,
      );
      await commercialService.save(
        SaveCommercialInsuranceCommand(
          id: insuranceId,
          name: original.name,
          insurerName: original.insurerName,
          category: original.category,
          coverageTerm: original.coverageTerm,
          coverageAmount: original.coverageAmount,
          insuredPersonIds: original.insuredPersonIds,
        ),
      );
      var saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.premiumPlan?.frequency, PremiumFrequency.annual);
      expect(saved.premiumPlan?.termCount, 20);
      expect(saved.premiumPlan?.amount, plan.amount);
      expect(saved.attachments.single.id, original.attachments.single.id);
      expect(
        saved.responsibilities.single.id,
        original.responsibilities.single.id,
      );
      expect(saved.insuredPersonIds, original.insuredPersonIds);

      await commercialService.deleteAttachment(
        insuranceId: insuranceId,
        attachmentId: saved.attachments.single.id,
      );
      saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.premiumPlan?.amount, plan.amount);
      await commercialService.updatePremiumPlan(
        insuranceId: insuranceId,
        premiumPlan: null,
      );
      saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.premiumPlan, isNull);
      expect(saved.name, original.name);
      expect(saved.coverageTerm.endDate, original.coverageTerm.endDate);
      expect(
        saved.responsibilities.single.id,
        original.responsibilities.single.id,
      );
    },
  );

  test('invalid payment configuration leaves the saved plan intact', () async {
    final person = await _savePerson(insuredPersonService, '示例成员');
    final insuranceId = await commercialService.save(
      _commercialCommand([person]),
    );
    const plan = PremiumPlan(
      frequency: PremiumFrequency.annual,
      amount: Money(minorUnits: 120000),
    );
    await commercialService.updatePremiumPlan(
      insuranceId: insuranceId,
      premiumPlan: plan,
    );
    for (final invalid in const [
      PremiumPlan(frequency: PremiumFrequency.annual, termCount: 0),
      PremiumPlan(
        frequency: PremiumFrequency.monthly,
        amount: Money(minorUnits: -1),
      ),
    ]) {
      await expectLater(
        commercialService.updatePremiumPlan(
          insuranceId: insuranceId,
          premiumPlan: invalid,
        ),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            InsuranceErrorCode.invalidCommand.code,
          ),
        ),
      );
      final saved = (await commercialInsurances.find(insuranceId))!;
      expect(saved.premiumPlan?.frequency, plan.frequency);
      expect(saved.premiumPlan?.amount, plan.amount);
      expect(saved.premiumPlan?.termCount, isNull);
    }
    await expectLater(
      commercialService.updatePremiumPlan(
        insuranceId: 'missing',
        premiumPlan: plan,
      ),
      throwsA(
        isA<BusinessException>().having(
          (error) => error.code,
          'code',
          InsuranceErrorCode.commercialInsuranceNotFound.code,
        ),
      ),
    );
  });

  test('overview counts in-force coverage per insured member', () async {
    final first = await _savePerson(insuredPersonService, '张一');
    final second = await _savePerson(insuredPersonService, '张二');
    final third = await _savePerson(insuredPersonService, '张三');

    await commercialService.save(
      _commercialCommand(
        [first],
        coverageAmount: CoverageAmount(
          amount: const Money(minorUnits: 10000000),
        ),
      ),
    );
    await commercialService.save(
      _commercialCommand(
        [first, second],
        coverageAmount: CoverageAmount(
          amount: const Money(minorUnits: 20000000),
        ),
      ),
    );
    await commercialService.save(
      _commercialCommand(
        [first, second, third],
        coverageTerm: CoverageTerm(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2025, 12, 31),
        ),
        coverageAmount: CoverageAmount(
          amount: const Money(minorUnits: 99999999),
        ),
      ),
    );
    await commercialService.save(
      _commercialCommand(
        [third],
        coverageTerm: CoverageTerm(
          startDate: DateTime(2025, 1, 1),
          lifetime: true,
        ),
      ),
    );

    final overview = await queryService.insuranceOverview();

    expect(overview.activePolicyCount, 3);
    expect(overview.coveredMemberCount, 3);
    expect(overview.coverageAmountTotal, const Money(minorUnits: 50000000));
    final firstCoverage = await queryService.memberCoverage(first);
    expect(firstCoverage!.activeCommercialInsuranceCount, 2);
    expect(
      firstCoverage.activeCoverageAmountTotal,
      const Money(minorUnits: 30000000),
    );
    expect(
      overview.commercialInsurances.map((item) => item.status),
      containsAll([
        InsuranceCoverageStatus.active,
        InsuranceCoverageStatus.ended,
        InsuranceCoverageStatus.lifetime,
      ]),
    );
  });

  test('removing the last commercial insured person is rejected', () async {
    final first = await _savePerson(insuredPersonService, '张一');
    final second = await _savePerson(insuredPersonService, '张二');
    final insuranceId = await commercialService.save(
      _commercialCommand([first, second]),
    );

    await commercialService.save(_commercialCommand([first], id: insuranceId));
    expect((await commercialInsurances.find(insuranceId))!.insuredPersonIds, [
      first,
    ]);

    await expectLater(
      commercialService.save(_commercialCommand([], id: insuranceId)),
      throwsA(
        isA<BusinessException>().having(
          (error) => error.code,
          'code',
          InsuranceErrorCode.invalidCommand.code,
        ),
      ),
    );
    expect((await commercialInsurances.find(insuranceId))!.insuredPersonIds, [
      first,
    ]);
  });

  test(
    'deleting commercial insurance cascades children and attachments',
    () async {
      final person = await _savePerson(insuredPersonService, '张一');
      final insuranceId = await commercialService.save(
        _commercialCommand([person]),
      );
      expect(await commercialService.addAttachments(insuranceId), 1);

      await commercialService.delete(insuranceId);

      expect(
        await database.select(database.commercialInsurances).get(),
        isEmpty,
      );
      expect(
        await database.select(database.commercialInsuranceInsuredPeople).get(),
        isEmpty,
      );
      expect(
        await database.select(database.coverageResponsibilities).get(),
        isEmpty,
      );
      expect(
        await database.select(database.responsibilityPoints).get(),
        isEmpty,
      );
      expect(
        await database.select(database.insuranceAttachments).get(),
        isEmpty,
      );
      expect(attachmentStorage.deletedKeys, {'attachments/contract.pdf'});

      await insuredPersonService.delete(person);
      expect(await database.select(database.insuredPeople).get(), isEmpty);
    },
  );

  test('social member and region edits retain contribution history', () async {
    final first = await _savePerson(insuredPersonService, '张一');
    final second = await _savePerson(insuredPersonService, '张二');
    final contribution = SocialContributionRecord(
      year: 2026,
      month: 1,
      contributionBase: Money(minorUnits: 800000),
      contributionAmount: Money(minorUnits: 160000),
      note: '正常缴费',
    );
    final id = await socialService.save(
      SaveSocialInsuranceCommand(
        insuredPersonId: first,
        region: '上海',
        insuranceType: SocialInsuranceType.medical,
        participantType: SocialParticipantType.employee,
        contributionRecords: [contribution],
      ),
    );
    final original = (await socialInsurances.find(id))!;

    await socialService.save(
      SaveSocialInsuranceCommand(
        id: id,
        insuredPersonId: second,
        region: '北京市 / 北京市',
        insuranceType: original.insuranceType,
        participantType: original.participantType,
        contributionRecords: original.contributionRecords,
      ),
    );

    final updated = (await socialInsurances.find(id))!;
    expect(updated.insuredPersonId, second);
    expect(updated.region, '北京市 / 北京市');
    expect(updated.createdAt, original.createdAt);
    expect(updated.contributionRecords, hasLength(1));
    final saved = updated.contributionRecords.single;
    expect(saved.period, '2026-01');
    expect(saved.contributionBase, contribution.contributionBase);
    expect(saved.contributionAmount, contribution.contributionAmount);
    expect(saved.note, '正常缴费');
  });

  test(
    'duplicate social months and historical type changes are rejected',
    () async {
      final person = await _savePerson(insuredPersonService, '张一');
      final contribution = SocialContributionRecord(
        year: 2026,
        month: 1,
        contributionBase: Money(minorUnits: 800000),
        contributionAmount: Money(minorUnits: 160000),
      );
      final medicalId = await socialService.save(
        SaveSocialInsuranceCommand(
          insuredPersonId: person,
          region: '上海',
          insuranceType: SocialInsuranceType.medical,
          participantType: SocialParticipantType.employee,
          contributionRecords: [contribution],
        ),
      );

      await expectLater(
        socialService.save(
          SaveSocialInsuranceCommand(
            insuredPersonId: person,
            region: '上海',
            insuranceType: SocialInsuranceType.medical,
            participantType: SocialParticipantType.employee,
            contributionRecords: [contribution, contribution],
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            InsuranceErrorCode.invalidCommand.code,
          ),
        ),
      );
      expect(
        (await socialInsurances.find(medicalId))!.contributionRecords,
        hasLength(1),
      );

      await expectLater(
        socialService.save(
          SaveSocialInsuranceCommand(
            id: medicalId,
            insuredPersonId: person,
            region: '上海',
            insuranceType: SocialInsuranceType.pension,
            participantType: SocialParticipantType.employee,
            contributionRecords: [contribution],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        socialService.save(
          SaveSocialInsuranceCommand(
            id: medicalId,
            insuredPersonId: person,
            region: '上海',
            insuranceType: SocialInsuranceType.medical,
            participantType: SocialParticipantType.resident,
            contributionRecords: [contribution],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect((await socialInsurances.find(medicalId))!.region, '上海');

      final pensionId = await socialService.save(
        SaveSocialInsuranceCommand(
          insuredPersonId: person,
          region: '上海',
          insuranceType: SocialInsuranceType.pension,
          participantType: SocialParticipantType.employee,
          contributionRecords: const [],
        ),
      );
      await expectLater(
        socialService.save(
          SaveSocialInsuranceCommand(
            id: pensionId,
            insuredPersonId: person,
            region: '上海',
            insuranceType: SocialInsuranceType.pension,
            participantType: SocialParticipantType.employee,
            contributionRecords: [contribution, contribution],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );

      await expectLater(
        insuredPersonService.delete(person),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            InsuranceErrorCode.insuredPersonInUse.code,
          ),
        ),
      );
    },
  );
}

Future<String> _savePerson(InsuredPersonAppService service, String name) {
  return service.save(
    SaveInsuredPersonCommand(
      name: name,
      birthDate: DateTime(1990, 6, 15),
      relationship: MemberRelationship.self,
      gender: MemberGender.unknown,
      avatarPreset: MemberAvatarPreset.blue,
    ),
  );
}

SaveCommercialInsuranceCommand _commercialCommand(
  List<String> personIds, {
  String? id,
  CoverageTerm? coverageTerm,
  CoverageAmount? coverageAmount,
  List<InsuranceResponsibilityInput>? responsibilities,
}) {
  return SaveCommercialInsuranceCommand(
    id: id,
    name: '家庭医疗险',
    insurerName: '示例保险',
    category: CommercialInsuranceCategory.medical,
    coverageTerm:
        coverageTerm ??
        CoverageTerm(
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2026, 12, 31),
        ),
    coverageAmount: coverageAmount,
    insuredPersonIds: personIds,
    responsibilities:
        responsibilities ??
        const [
          InsuranceResponsibilityInput(
            kind: ResponsibilityKind.medical,
            name: '一般医疗',
            points: [
              InsuranceResponsibilityPointInput(
                label: '住院报销',
                value: '最高 100 万元',
              ),
            ],
          ),
        ],
  );
}

class _MemoryAttachmentStorage implements InsuranceAttachmentStorage {
  final deletedKeys = <String>{};

  @override
  Future<List<InsuranceAttachmentDraft>> pickAndStore({
    required String commercialInsuranceId,
  }) async {
    return const [
      InsuranceAttachmentDraft(
        fileName: 'contract.pdf',
        storageKey: 'attachments/contract.pdf',
        mimeType: 'application/pdf',
      ),
    ];
  }

  @override
  Future<void> delete(String storageKey) async {
    deletedKeys.add(storageKey);
  }

  @override
  Future<void> open(String storageKey) async {}
}
