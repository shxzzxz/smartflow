import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/insurance/insurance_command_api.dart';
import 'package:smartflow/application/insurance/insurance_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/insurance/presentation/insurance_coverage_field.dart';
import 'package:smartflow/feature/insurance/view_model/commercial_insurance_detail_view_model.dart';
import 'package:smartflow/feature/insurance/view_model/commercial_insurance_form_view_model.dart';
import 'package:smartflow/feature/insurance/view_model/commercial_insurance_responsibilities_view_model.dart';
import 'package:smartflow/feature/insurance/view_model/social_insurance_detail_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_commercial_insurance_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_insured_person_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_social_insurance_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;
  late InsuranceCoverageQueryService query;

  setUp(() async {
    database = createTestDatabase();
    await _seed(database);
    query = InsuranceCoverageQueryServiceImpl(
      insuredPeople: DriftInsuredPersonRepository(database),
      commercialInsurances: DriftCommercialInsuranceRepository(database),
      socialInsurances: DriftSocialInsuranceRepository(database),
      now: () => DateTime(2026, 11, 5),
    );
  });
  tearDown(() => database.close());

  ProviderContainer container({bool failCommercialSave = false}) {
    final value = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        insuranceCoverageQueryServiceProvider.overrideWithValue(query),
        if (failCommercialSave)
          commercialInsuranceAppServiceProvider.overrideWithValue(
            _FailingCommercialService(),
          ),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    'filtered responsibility reordering preserves hidden positions and point identities',
    () async {
      final scope = container();
      final provider = commercialInsuranceResponsibilitiesViewModelProvider(
        'policy',
      );
      final subscription = scope.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await scope.read(provider.future);
      final notifier = scope.read(provider.notifier);
      notifier.setKind(ResponsibilityKind.medical);
      final result = await notifier.reorderResponsibilities(0, 1);
      expect(result, isA<UiActionSuccess<String>>());
      var saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
      expect(saved.responsibilities.map((item) => item.id), ['c', 'b', 'a']);
      expect(saved.responsibilities.map((item) => item.order), [0, 1, 2]);
      expect(
        scope.read(provider).requireValue!.selectedKind,
        ResponsibilityKind.medical,
      );

      await notifier.reorderPoints('a', 0, 2);
      saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
      final points = saved.responsibilities
          .singleWhere((item) => item.id == 'a')
          .points;
      expect(points.map((point) => point.id), ['p2', 'p3', 'p1']);
      expect(points.map((point) => point.order), [0, 1, 2]);
      expect(
        saved.responsibilities
            .singleWhere((item) => item.id == 'a')
            .description,
        '责任甲说明',
      );
      expect(saved.coverageAmountDescription, '共享保额');
      expect(saved.coverageSummary, '初始总结');
    },
  );

  test(
    'point additions, edits and removals preserve responsibility descriptions',
    () async {
      final scope = container();
      final provider = commercialInsuranceResponsibilitiesViewModelProvider(
        'policy',
      );
      final subscription = scope.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await scope.read(provider.future);
      final notifier = scope.read(provider.notifier);

      expect(
        await notifier.upsertPoint(
          'a',
          InsurancePointDraft(
            id: notifier.newPointDraftId(),
            label: '补充要点',
            value: '新增内容',
          ),
        ),
        isA<UiActionSuccess<String>>(),
      );
      var responsibility = (await query.commercialInsuranceDetail(
        'policy',
      ))!.insurance.responsibilities.singleWhere((item) => item.id == 'a');
      expect(responsibility.description, '责任甲说明');
      final added = responsibility.points.singleWhere(
        (point) => point.label == '补充要点',
      );
      await notifier.upsertPoint(
        'a',
        InsurancePointDraft(id: added.id, label: added.label, value: '编辑内容'),
      );
      responsibility = (await query.commercialInsuranceDetail(
        'policy',
      ))!.insurance.responsibilities.singleWhere((item) => item.id == 'a');
      expect(responsibility.description, '责任甲说明');
      expect(
        responsibility.points
            .singleWhere((point) => point.id == added.id)
            .value,
        '编辑内容',
      );

      await notifier.removePoint('a', added.id);
      responsibility = (await query.commercialInsuranceDetail(
        'policy',
      ))!.insurance.responsibilities.singleWhere((item) => item.id == 'a');
      expect(responsibility.description, '责任甲说明');
      expect(responsibility.points.map((point) => point.id), [
        'p1',
        'p2',
        'p3',
      ]);
    },
  );

  test('a failed reorder restores the displayed order and selection', () async {
    final scope = container(failCommercialSave: true);
    final provider = commercialInsuranceResponsibilitiesViewModelProvider(
      'policy',
    );
    final subscription = scope.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await scope.read(provider.future);
    final notifier = scope.read(provider.notifier);
    notifier.setKind(ResponsibilityKind.medical);
    final result = await notifier.reorderResponsibilities(0, 1);
    expect(result, isA<UiActionFailure<String>>());
    final displayed = scope.read(provider).requireValue!;
    expect(displayed.responsibilities.map((item) => item.id), ['a', 'b', 'c']);
    expect(displayed.selectedKind, ResponsibilityKind.medical);
    expect(displayed.submitting, isFalse);
    final saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
    expect(saved.responsibilities.map((item) => item.id), ['a', 'b', 'c']);
  });

  test(
    'coverage fields save independently, survive basic edits and clear individually',
    () async {
      final scope = container();
      final provider = commercialInsuranceResponsibilitiesViewModelProvider(
        'policy',
      );
      final subscription = scope.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await scope.read(provider.future);
      final notifier = scope.read(provider.notifier);
      final expectedCoverage = <InsuranceCoverageField, String?>{
        InsuranceCoverageField.summary: '初始总结',
        InsuranceCoverageField.highlights: '初始亮点',
        InsuranceCoverageField.waitingPeriod: '疾病30天；意外无等待期',
        InsuranceCoverageField.exclusions: '按承保约定处理\n特别除外约定',
      };
      for (final (field, input, expected) in const [
        (InsuranceCoverageField.summary, '  覆盖住院医疗  ', '覆盖住院医疗'),
        (InsuranceCoverageField.highlights, '  无免赔额  ', '无免赔额'),
        (
          InsuranceCoverageField.waitingPeriod,
          '  疾病60天；意外无等待期  ',
          '疾病60天；意外无等待期',
        ),
        (
          InsuranceCoverageField.exclusions,
          '  既往症相关责任除外\n特定疾病除外  ',
          '既往症相关责任除外\n特定疾病除外',
        ),
      ]) {
        expect(
          await notifier.saveCoverageField(field, input),
          isA<UiActionSuccess<String>>(),
        );
        expectedCoverage[field] = expected;
        final saved = (await query.commercialInsuranceDetail(
          'policy',
        ))!.insurance;
        expect(
          saved.coverageSummary,
          expectedCoverage[InsuranceCoverageField.summary],
        );
        expect(
          saved.coverageHighlights,
          expectedCoverage[InsuranceCoverageField.highlights],
        );
        expect(
          saved.waitingPeriodDescription,
          expectedCoverage[InsuranceCoverageField.waitingPeriod],
        );
        expect(
          saved.exclusionsDescription,
          expectedCoverage[InsuranceCoverageField.exclusions],
        );
      }

      final form = commercialInsuranceFormViewModelProvider('policy', null);
      final formSubscription = scope.listen(form, (_, _) {});
      addTearDown(formSubscription.close);
      await scope.read(form.future);
      final initial = scope.read(form).requireValue!.initialValues;
      expect(initial.policyholderName, '投保人甲');
      expect(initial.beneficiaryDescription, '法定');
      final detailProvider = commercialInsuranceDetailViewModelProvider(
        'policy',
      );
      final detailSubscription = scope.listen(detailProvider, (_, _) {});
      addTearDown(detailSubscription.close);
      await scope.read(detailProvider.future);
      expect(
        await scope
            .read(detailProvider.notifier)
            .savePremiumPlan(
              const PremiumPlan(
                frequency: PremiumFrequency.annual,
                termCount: 20,
                amount: Money(minorUnits: 120000),
              ),
            ),
        isA<UiActionSuccess<void>>(),
      );
      await scope.read(detailProvider.future);
      final result = await scope
          .read(form.notifier)
          .save(
            nameText: '新的保单名称',
            insurerNameText: '示例保险',
            productFormText: '长期医疗',
            coverageAmountText: '150000',
          );
      expect(result, isA<UiActionSuccess<String>>());
      var saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
      expect(saved.coverageSummary, '覆盖住院医疗');
      expect(saved.coverageHighlights, '无免赔额');
      expect(saved.coverageAmountDescription, '共享保额');
      expect(saved.policyholderName, '投保人甲');
      expect(saved.beneficiaryDescription, '法定');
      expect(saved.waitingPeriodDescription, '疾病60天；意外无等待期');
      expect(saved.exclusionsDescription, '既往症相关责任除外\n特定疾病除外');
      expect(saved.premiumPlan?.frequency, PremiumFrequency.annual);
      expect(saved.premiumPlan?.termCount, 20);
      expect(saved.premiumPlan?.amount?.minorUnits, 120000);

      for (final field in InsuranceCoverageField.values) {
        expect(
          await notifier.saveCoverageField(field, '  '),
          isA<UiActionSuccess<String>>(),
        );
        expectedCoverage[field] = null;
        saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
        expect(
          saved.coverageSummary,
          expectedCoverage[InsuranceCoverageField.summary],
        );
        expect(
          saved.coverageHighlights,
          expectedCoverage[InsuranceCoverageField.highlights],
        );
        expect(
          saved.waitingPeriodDescription,
          expectedCoverage[InsuranceCoverageField.waitingPeriod],
        );
        expect(
          saved.exclusionsDescription,
          expectedCoverage[InsuranceCoverageField.exclusions],
        );
      }
      saved = (await query.commercialInsuranceDetail('policy'))!.insurance;
      expect(saved.coverageSummary, isNull);
      expect(saved.coverageHighlights, isNull);
      expect(saved.waitingPeriodDescription, isNull);
      expect(saved.exclusionsDescription, isNull);
      expect(saved.name, '新的保单名称');
      expect(saved.coverageAmount?.amount?.minorUnits, 15000000);
      expect(saved.coverageAmountDescription, '共享保额');
      expect(saved.premiumPlan?.amount?.minorUnits, 120000);
    },
  );

  test(
    'social annual and monthly records coexist and duplicate periods never overwrite facts',
    () async {
      final scope = container();
      final provider = socialInsuranceDetailViewModelProvider('social');
      final subscription = scope.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await scope.read(provider.future);
      final notifier = scope.read(provider.notifier);
      final result = await notifier.saveContributionRecord(
        year: 2026,
        contributionAmount: const Money(minorUnits: 200000),
        note: '  年度补缴  ',
      );
      expect(result, isA<UiActionSuccess<void>>());
      await scope.read(provider.future);
      expect(
        await notifier.saveContributionRecord(
          year: 2026,
          contributionAmount: const Money(minorUnits: 999999),
        ),
        isA<UiActionFailure<void>>(),
      );
      expect(
        await notifier.saveContributionRecord(
          year: 2026,
          month: 1,
          contributionAmount: const Money(minorUnits: 999999),
        ),
        isA<UiActionFailure<void>>(),
      );

      await notifier.saveContributionRecord(
        year: 2026,
        month: 2,
        contributionBase: Money.zero(),
        contributionAmount: const Money(minorUnits: 160000),
      );
      await scope.read(provider.future);
      expect(
        await notifier.saveContributionRecord(
          originalPeriod: '2026',
          year: 2026,
          month: 2,
          contributionAmount: const Money(minorUnits: 50000),
        ),
        isA<UiActionFailure<void>>(),
      );
      final records = (await query.socialInsuranceDetail(
        'social',
      ))!.insurance.contributionRecords;
      expect(records.map((record) => record.period), [
        '2026',
        '2026-01',
        '2026-02',
      ]);
      final annual = records.singleWhere((record) => record.month == null);
      expect(annual.contributionAmount?.minorUnits, 200000);
      expect(annual.contributionBase, isNull);
      expect(annual.note, '年度补缴');
      final legacy = records.singleWhere(
        (record) => record.period == '2026-01',
      );
      expect(legacy.contributionBase?.minorUnits, 800000);
      expect(legacy.contributionAmount, isNull);

      await notifier.removeContributionRecord('2026');
      await scope.read(provider.future);
      expect(
        (await query.socialInsuranceDetail(
          'social',
        ))!.insurance.contributionRecords.map((record) => record.period),
        ['2026-01', '2026-02'],
      );
    },
  );
}

class _FailingCommercialService extends Fake
    implements CommercialInsuranceAppService {
  @override
  Future<String> save(SaveCommercialInsuranceCommand command) async {
    throw BusinessException(
      InsuranceErrorCode.invalidCommand,
      message: '模拟保存失败',
    );
  }
}

Future<void> _seed(AppDatabase database) async {
  final date = DateTime(2026, 1, 1);
  await DriftInsuredPersonRepository(database).save(
    InsuredPerson(
      id: 'person',
      name: '示例成员',
      birthDate: DateTime(1990, 1, 1),
      createdAt: date,
      updatedAt: date,
    ),
  );
  await DriftCommercialInsuranceRepository(database).save(
    CommercialInsurance(
      id: 'policy',
      name: '示例医疗险',
      insurerName: '示例保险',
      category: CommercialInsuranceCategory.medical,
      coverageTerm: CoverageTerm(startDate: DateTime(2025, 1, 1)),
      coverageAmount: const CoverageAmount(amount: Money(minorUnits: 10000000)),
      coverageAmountDescription: '共享保额',
      coverageSummary: '初始总结',
      coverageHighlights: '初始亮点',
      policyholderName: '投保人甲',
      beneficiaryDescription: '法定',
      waitingPeriodDescription: '疾病30天；意外无等待期',
      exclusionsDescription: '按承保约定处理\n特别除外约定',
      insuredPersonIds: const ['person'],
      responsibilities: [
        CoverageResponsibility(
          id: 'a',
          kind: ResponsibilityKind.medical,
          name: '责任甲',
          description: '责任甲说明',
          order: 0,
          points: const [
            ResponsibilityPoint(id: 'p1', label: '要点一', value: '内容一', order: 0),
            ResponsibilityPoint(id: 'p2', label: '要点二', value: '内容二', order: 1),
            ResponsibilityPoint(id: 'p3', label: '要点三', value: '内容三', order: 2),
          ],
        ),
        CoverageResponsibility(
          id: 'b',
          kind: ResponsibilityKind.death,
          name: '责任乙',
          order: 1,
          points: const [],
        ),
        CoverageResponsibility(
          id: 'c',
          kind: ResponsibilityKind.medical,
          name: '责任丙',
          order: 2,
          points: const [],
        ),
      ],
      attachments: const [],
      createdAt: date,
      updatedAt: date,
    ),
  );
  await DriftSocialInsuranceRepository(database).save(
    SocialInsurance(
      id: 'social',
      insuredPersonId: 'person',
      region: '浙江省 / 杭州市',
      insuranceType: SocialInsuranceType.medical,
      participantType: SocialParticipantType.employee,
      contributionRecords: const [
        SocialContributionRecord(
          year: 2026,
          month: 1,
          contributionBase: Money(minorUnits: 800000),
        ),
      ],
      createdAt: date,
      updatedAt: date,
    ),
  );
}
