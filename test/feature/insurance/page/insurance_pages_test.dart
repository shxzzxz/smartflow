import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/insurance/coverage_overview/query/insurance_coverage_query_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_choice_chip_group.dart';
import 'package:smartflow/domain/insurance/entity/commercial_insurance.dart';
import 'package:smartflow/domain/insurance/entity/insured_person.dart';
import 'package:smartflow/domain/insurance/entity/social_medical_insurance.dart';
import 'package:smartflow/domain/insurance/entity/social_pension_insurance.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_amount.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_responsibility.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_term.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/domain/insurance/valobj/social_contribution_record.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_detail_page.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_form_page.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_list_page.dart';
import 'package:smartflow/feature/insurance/page/insurance_members_page.dart';
import 'package:smartflow/feature/insurance/page/insurance_overview_page.dart';
import 'package:smartflow/feature/insurance/page/insurance_responsibility_detail_page.dart';
import 'package:smartflow/feature/insurance/page/insured_person_form_page.dart';
import 'package:smartflow/feature/insurance/page/member_coverage_page.dart';
import 'package:smartflow/feature/insurance/page/social_insurance_detail_page.dart';
import 'package:smartflow/feature/insurance/page/social_insurance_form_page.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_commercial_insurance_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_insured_person_repository.dart';
import 'package:smartflow/infrastructure/insurance/repository/drift_social_insurance_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;
  late InsuranceCoverageQueryServiceImpl queryService;

  setUp(() {
    database = createTestDatabase();
    queryService = InsuranceCoverageQueryServiceImpl(
      insuredPeople: DriftInsuredPersonRepository(database),
      commercialInsurances: DriftCommercialInsuranceRepository(database),
      socialInsurances: DriftSocialInsuranceRepository(database),
      now: () => DateTime(2026, 11, 5),
    );
  });

  tearDown(() => database.close());

  testWidgets('shows the insurance overview with placeholder annual premium', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const InsuranceOverviewPage(),
        ),
        GoRoute(
          path: '/insurance/members/:id',
          builder: (context, state) =>
              Scaffold(body: Text('成员:${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('家庭保障概况'), findsOneWidget);
    expect(find.text('年度保费'), findsOneWidget);
    expect(find.text('12,000'), findsOneWidget);
    expect(find.text('¥ 12,000'), findsNothing);
    expect(find.text('家庭成员保障'), findsOneWidget);
    expect(find.text('张一'), findsOneWidget);
    expect(find.text('张二'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('insurance-overview-member-person-2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('成员:person-2'), findsOneWidget);
  });

  testWidgets('overview fits a phone-width layout', (tester) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const InsuranceOverviewPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      database,
      queryService,
      router,
      size: const Size(390, 844),
    );

    expect(find.text('家庭保障概况'), findsOneWidget);
    expect(find.text('12,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview loads through the production provider graph', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const InsuranceOverviewPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('家庭保障概况'), findsOneWidget);
    expect(find.text('加载失败，点击重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists all members and navigates to member coverage', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const InsuranceMembersPage(),
        ),
        GoRoute(
          path: '/insurance/members/:id',
          builder: (context, state) =>
              Scaffold(body: Text('成员:${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('张一'), findsOneWidget);
    expect(find.text('张二'), findsOneWidget);
    expect(find.text('其他 · 未知 · 36 岁'), findsNWidgets(2));
    expect(find.textContaining('份商业保险'), findsNothing);
    expect(find.text('社保医保'), findsNothing);
    expect(find.text('社保养老'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('insurance-member-person-2')));
    await tester.pumpAndSettle();
    expect(find.text('成员:person-2'), findsOneWidget);
  });

  testWidgets('saves the expanded member profile', (tester) async {
    final router = _formRouter(const InsuredPersonFormPage());
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    expect(find.text('新增成员'), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);
    final relationshipRow = find.byType(
      AppPlainChoiceChipFormRow<MemberRelationship>,
    );
    final genderRow = find.byType(AppPlainChoiceChipFormRow<MemberGender>);
    expect(tester.widget<Text>(find.text('本人')).style?.fontSize, 12);
    expect(
      tester.getSize(genderRow).height,
      tester.getSize(relationshipRow).height,
    );

    await tester.enterText(find.byType(TextField).at(0), '李四');
    await tester.tap(find.text('配偶'));
    await tester.tap(find.text('女'));
    await tester.enterText(find.byType(TextField).at(1), '主要保障人');

    await tester.tap(find.text('请选择出生日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().day}').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-avatar-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-avatar-preset-green')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('打开表单'), findsOneWidget);
    final people = await DriftInsuredPersonRepository(database).list();
    expect(people, hasLength(1));
    expect(people.single.name, '李四');
    expect(people.single.relationship, MemberRelationship.spouse);
    expect(people.single.gender, MemberGender.female);
    expect(people.single.note, '主要保障人');
    expect(people.single.avatarPreset, MemberAvatarPreset.green);
  });

  testWidgets('groups member coverage and opens the shared policy detail', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const MemberCoveragePage(insuredPersonId: 'person-1'),
        ),
        GoRoute(
          path: '/insurance/commercial/:id',
          builder: (context, state) =>
              Scaffold(body: Text('保单:${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('关联保单'), findsOneWidget);
    expect(find.text('其他 · 1990-06-15'), findsOneWidget);
    expect(find.textContaining('出生：'), findsNothing);
    expect(find.text('社保'), findsOneWidget);
    expect(find.text('社保医保'), findsOneWidget);
    expect(find.text('社保养老'), findsOneWidget);
    expect(find.text('100,000'), findsOneWidget);
    expect(find.textContaining('¥ 100,000'), findsNothing);
    expect(
      find.byKey(const ValueKey('coverage-commercial-commercial-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coverage-social-medical-medical-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coverage-social-pension-pension-1')),
      findsOneWidget,
    );
    const commercialAddKey = ValueKey('coverage-add-commercial');
    const socialAddKey = ValueKey('coverage-add-social');
    final primary = Theme.of(
      tester.element(find.byKey(commercialAddKey)),
    ).colorScheme.primary;
    for (final key in [commercialAddKey, socialAddKey]) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.text('新增')),
        findsOneWidget,
      );
      final iconFinder = find.descendant(
        of: find.byKey(key),
        matching: find.byIcon(RemixIcons.add_line),
      );
      expect(IconTheme.of(tester.element(iconFinder)).color, primary);
    }
    await tester.tap(find.byKey(socialAddKey));
    await tester.pumpAndSettle();
    expect(find.text('新增社保医保'), findsOneWidget);
    expect(find.text('新增社保养老'), findsOneWidget);
    await tester.tapAt(const Offset(AppSpacing.space4, AppSpacing.space4));
    await tester.pumpAndSettle();
    final titleRect = tester.getRect(find.text('家庭医疗险'));
    final badgeRect = tester.getRect(find.text('保障中'));
    expect(badgeRect.left - titleRect.right, lessThan(AppSpacing.space16));

    await tester.tap(
      find.byKey(const ValueKey('coverage-commercial-commercial-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('保单:commercial-1'), findsOneWidget);
  });

  testWidgets('lists and filters commercial policies', (tester) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CommercialInsuranceListPage(),
        ),
        GoRoute(
          path: '/insurance/commercial/:id',
          builder: (context, state) =>
              Scaffold(body: Text('保单:${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('保单管理'), findsOneWidget);
    expect(find.text('家庭医疗险'), findsOneWidget);
    expect(find.text('示例保险 · 保额 100,000'), findsOneWidget);
    expect(find.text('被保险人：张一'), findsOneWidget);
    expect(find.text('医疗险 (1)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('coverage-commercial-commercial-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('保单:commercial-1'), findsOneWidget);
  });

  testWidgets('policy list and detail fit a phone-width layout', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CommercialInsuranceListPage(),
        ),
        GoRoute(
          path: '/insurance/commercial/:id/responsibilities/:responsibilityId',
          builder: (context, state) => InsuranceResponsibilityDetailPage(
            insuranceId: state.pathParameters['id']!,
            responsibilityId: state.pathParameters['responsibilityId']!,
          ),
        ),
        GoRoute(
          path: '/insurance/commercial/:id',
          builder: (context, state) => CommercialInsuranceDetailPage(
            insuranceId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      database,
      queryService,
      router,
      size: const Size(390, 844),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byKey(const ValueKey('coverage-commercial-commercial-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('保单详情'), findsOneWidget);
    expect(find.text('保障责任'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('insurance-responsibility-responsibility-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('保障责任详情'), findsOneWidget);
    expect(find.text('住院报销'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a social insurance form with the selected member', (
    tester,
  ) async {
    await DriftInsuredPersonRepository(
      database,
    ).save(_person('person-1', '张一'));
    final router = _formRouter(
      const SocialInsuranceFormPage(
        sourceType: InsuranceSourceType.socialMedical,
        initialInsuredPersonId: 'person-1',
      ),
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    expect(find.text('缴费记录'), findsNothing);
    await tester.enterText(find.byType(TextField), '上海');
    await tester.ensureVisible(find.text('保存记录'));
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(find.text('打开表单'), findsOneWidget);
    final records = await DriftSocialInsuranceRepository(
      database,
    ).listMedical();
    expect(records.single.region, '上海');
    expect(records.single.insuredPersonId, 'person-1');
    expect(records.single.contributionRecords, isEmpty);
  });

  testWidgets('adds a contribution record from social insurance detail', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SocialInsuranceDetailPage(
            insuranceId: 'medical-1',
            sourceType: InsuranceSourceType.socialMedical,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('1 条'), findsOneWidget);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('添加缴费记录'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '9000');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('2 条'), findsOneWidget);
    final records = await DriftSocialInsuranceRepository(
      database,
    ).findMedical('medical-1');
    expect(records!.contributionRecords, hasLength(2));
  });

  testWidgets('commercial form keeps compact choice rows at phone width', (
    tester,
  ) async {
    await DriftInsuredPersonRepository(
      database,
    ).save(_person('person-1', '张一'));
    final router = _formRouter(
      const CommercialInsuranceFormPage(initialInsuredPersonId: 'person-1'),
    );
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      database,
      queryService,
      router,
      size: const Size(390, 844),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    final categoryRow = find.byKey(
      const ValueKey('commercial-category-choice'),
    );
    final frequencyRow = find.byKey(
      const ValueKey('commercial-premium-frequency-choice'),
    );
    int rowPosition(Finder row, String label) {
      final text = find.descendant(of: row, matching: find.text(label));
      return (tester.getTopLeft(text).dy * 10).round();
    }

    const categoryLabels = ['医疗', '重疾', '意外', '寿险', '其他'];
    final categoryRows = {
      for (final label in categoryLabels) rowPosition(categoryRow, label),
    };
    expect(categoryRows, hasLength(1));

    const frequencyLabels = ['一次性', '月缴', '季缴', '半年缴', '年缴', '其他'];
    final frequencyRows = {
      for (final label in frequencyLabels) rowPosition(frequencyRow, label),
    };
    expect(frequencyRows, hasLength(2));

    final categoryHeight = tester.getSize(categoryRow).height;
    await tester.ensureVisible(frequencyRow);
    await tester.pumpAndSettle();

    expect(tester.getSize(frequencyRow).height, categoryHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a commercial insurance form for the initial member', (
    tester,
  ) async {
    await DriftInsuredPersonRepository(
      database,
    ).save(_person('person-1', '张一'));
    final router = _formRouter(
      const CommercialInsuranceFormPage(initialInsuredPersonId: 'person-1'),
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '百万医疗');
    await tester.enterText(find.byType(TextField).at(1), '示例保险');
    expect(
      find.byType(AppPlainChoiceChipFormRow<CommercialInsuranceCategory>),
      findsOneWidget,
    );
    expect(
      find.byType(AppPlainChoiceChipFormRow<PremiumFrequency>),
      findsOneWidget,
    );
    final frequencyRow = find.byKey(
      const ValueKey('commercial-premium-frequency-choice'),
    );
    expect(
      find.descendant(of: frequencyRow, matching: find.text('其他')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: frequencyRow, matching: find.text('不定期')),
      findsNothing,
    );
    expect(
      find.descendant(of: frequencyRow, matching: find.text('未记录')),
      findsNothing,
    );
    await tester.ensureVisible(find.text('意外'));
    await tester.tap(find.text('意外'));
    await tester.ensureVisible(find.text('保存商业保险'));
    await tester.tap(find.text('保存商业保险'));
    await tester.pumpAndSettle();

    expect(find.text('打开表单'), findsOneWidget);
    final records = await DriftCommercialInsuranceRepository(
      database,
    ).list(insuredPersonId: 'person-1');
    expect(records.single.name, '百万医疗');
    expect(records.single.insuredPersonIds, ['person-1']);
    expect(records.single.category, CommercialInsuranceCategory.accident);
    expect(records.single.premiumPlan?.frequency, PremiumFrequency.other);
  });
}

Future<void> _pumpRouter(
  WidgetTester tester,
  AppDatabase database,
  InsuranceCoverageQueryServiceImpl queryService,
  GoRouter router, {
  Size size = const Size(1080, 2200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        insuranceCoverageQueryServiceProvider.overrideWithValue(queryService),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _formRouter(Widget form) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/form'),
            child: const Text('打开表单'),
          ),
        ),
      ),
      GoRoute(path: '/form', builder: (context, state) => form),
    ],
  );
}

Future<void> _seedMembers(AppDatabase database) async {
  final people = DriftInsuredPersonRepository(database);
  final commercial = DriftCommercialInsuranceRepository(database);
  final social = DriftSocialInsuranceRepository(database);
  final createdAt = DateTime(2026, 1, 1);
  await people.save(_person('person-1', '张一'));
  await people.save(_person('person-2', '张二'));
  await commercial.save(
    CommercialInsurance(
      id: 'commercial-1',
      name: '家庭医疗险',
      insurerName: '示例保险',
      category: CommercialInsuranceCategory.medical,
      coverageTerm: CoverageTerm(
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2026, 12, 31),
      ),
      coverageAmount: CoverageAmount(amount: Money(minorUnits: 10000000)),
      insuredPersonIds: const ['person-1'],
      responsibilities: [
        CoverageResponsibility(
          id: 'responsibility-1',
          kind: ResponsibilityKind.medical,
          name: '医疗',
          points: const [
            ResponsibilityPoint(
              id: 'point-1',
              label: '住院报销',
              value: '最高 100 万元',
              order: 0,
            ),
          ],
          order: 0,
        ),
      ],
      attachments: const [],
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  await social.saveMedical(
    SocialMedicalInsurance(
      id: 'medical-1',
      insuredPersonId: 'person-1',
      region: '上海',
      participantType: SocialParticipantType.employee,
      contributionRecords: [
        SocialContributionRecord(
          month: MonthKey(year: 2026, month: 1),
          contributionBase: Money(minorUnits: 800000),
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  await social.savePension(
    SocialPensionInsurance(
      id: 'pension-1',
      insuredPersonId: 'person-1',
      region: '上海',
      participantType: SocialParticipantType.employee,
      contributionRecords: const [],
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
}

InsuredPerson _person(String id, String name) {
  return InsuredPerson(
    id: id,
    name: name,
    birthDate: DateTime(1990, 6, 15),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}
