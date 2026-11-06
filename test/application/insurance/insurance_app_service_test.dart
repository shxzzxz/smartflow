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
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_amount.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_term.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_error_code.dart';
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

  test(
    'duplicate social months and historical identity changes are rejected',
    () async {
      final person = await _savePerson(insuredPersonService, '张一');
      final contribution = SocialContributionRecord(
        month: MonthKey(year: 2026, month: 1),
        contributionBase: Money(minorUnits: 800000),
      );
      final medicalId = await socialService.saveMedical(
        SaveSocialInsuranceCommand(
          insuredPersonId: person,
          region: '上海',
          participantType: SocialParticipantType.employee,
          contributionRecords: [contribution],
        ),
      );

      await expectLater(
        socialService.saveMedical(
          SaveSocialInsuranceCommand(
            insuredPersonId: person,
            region: '上海',
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
        (await socialInsurances.findMedical(medicalId))!.contributionRecords,
        hasLength(1),
      );

      await expectLater(
        socialService.saveMedical(
          SaveSocialInsuranceCommand(
            id: medicalId,
            insuredPersonId: person,
            region: '北京',
            participantType: SocialParticipantType.employee,
            contributionRecords: [contribution],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        socialService.saveMedical(
          SaveSocialInsuranceCommand(
            id: medicalId,
            insuredPersonId: person,
            region: '上海',
            participantType: SocialParticipantType.resident,
            contributionRecords: [contribution],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect((await socialInsurances.findMedical(medicalId))!.region, '上海');

      final pensionId = await socialService.savePension(
        SaveSocialInsuranceCommand(
          insuredPersonId: person,
          region: '上海',
          participantType: SocialParticipantType.employee,
          contributionRecords: const [],
        ),
      );
      await expectLater(
        socialService.savePension(
          SaveSocialInsuranceCommand(
            id: pensionId,
            insuredPersonId: person,
            region: '上海',
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
    responsibilities: const [
      InsuranceResponsibilityInput(
        kind: ResponsibilityKind.medical,
        points: [
          InsuranceResponsibilityPointInput(label: '住院报销', value: '最高 100 万元'),
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
