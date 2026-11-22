import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/insurance/attachment/port/insurance_attachment_storage.dart';
import 'package:smartflow/application/insurance/coverage_overview/query/insurance_coverage_query_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_choice_chip_group.dart';
import 'package:smartflow/design_system/widget/app_region_picker.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/domain/insurance/entity/commercial_insurance.dart';
import 'package:smartflow/domain/insurance/entity/insured_person.dart';
import 'package:smartflow/domain/insurance/entity/social_insurance.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_amount.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_responsibility.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_term.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/domain/insurance/valobj/social_contribution_record.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_detail_page.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_form_page.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_list_page.dart';
import 'package:smartflow/feature/insurance/page/commercial_insurance_responsibilities_page.dart';
import 'package:smartflow/feature/insurance/page/insurance_members_page.dart';
import 'package:smartflow/feature/insurance/page/insurance_overview_page.dart';
import 'package:smartflow/feature/insurance/page/insured_person_form_page.dart';
import 'package:smartflow/feature/insurance/page/member_coverage_page.dart';
import 'package:smartflow/feature/insurance/page/social_insurance_detail_page.dart';
import 'package:smartflow/feature/insurance/page/social_insurance_form_page.dart';
import 'package:smartflow/feature/shared/presentation/china_region_data.dart';
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
    for (final preset in MemberAvatarPreset.values) {
      expect(
        find.byKey(ValueKey('member-avatar-preset-${preset.name}')),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.byKey(const ValueKey('member-avatar-preset-brother')),
    );
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
    expect(people.single.avatarPreset, MemberAvatarPreset.brother);
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
        GoRoute(
          path: '/insurance/social/new',
          builder: (context, state) => const Scaffold(body: Text('新增社保表单')),
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
    expect(find.text('10 万'), findsOneWidget);
    expect(find.textContaining('¥ 10 万'), findsNothing);
    expect(
      find.byKey(const ValueKey('coverage-commercial-commercial-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coverage-social-medical-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coverage-social-pension-1')),
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
    expect(find.text('新增社保表单'), findsOneWidget);
    router.pop();
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
    expect(find.text('示例保险 · 保额 10 万'), findsOneWidget);
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
    expect(find.text('基本信息'), findsNothing);
    expect(find.text('保障期限至'), findsOneWidget);
    expect(find.text('保障概要'), findsOneWidget);
    expect(find.text('保障亮点'), findsOneWidget);
    expect(find.text('张一'), findsOneWidget);
    expect(find.text('2026/12/31'), findsOneWidget);
    expect(find.text('保额说明'), findsNothing);
    expect(find.text('缴费配置'), findsOneWidget);
    expect(find.text('附件上传'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(
      find.byKey(const ValueKey('insurance-responsibility-responsibility-1')),
      findsNothing,
    );
    expect(find.text('住院报销'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uploads attachments from the action bar and deletes by long press',
    (tester) async {
      await _seedMembers(database);
      final storage = _TestAttachmentStorage();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CommercialInsuranceDetailPage(
              insuranceId: 'commercial-1',
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
        attachmentStorage: storage,
      );

      expect(find.text('合同附件'), findsOneWidget);
      expect(find.text('暂无合同附件'), findsOneWidget);
      expect(find.text('添加附件'), findsNothing);
      await tester.tap(find.text('附件上传'));
      await tester.pumpAndSettle();

      final detail = (await queryService.commercialInsuranceDetail(
        'commercial-1',
      ))!;
      final attachment = detail.insurance.attachments.single;
      final row = find.byKey(ValueKey('insurance-attachment-${attachment.id}'));
      await tester.dragUntilVisible(
        row,
        find.byType(Scrollable).first,
        const Offset(0, -250),
      );
      expect(find.text('合同附件'), findsOneWidget);
      expect(find.byTooltip('删除附件'), findsNothing);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(storage.openedKeys, ['attachments/test-contract.pdf']);

      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.text('删除附件'), findsOneWidget);
      expect(storage.deletedKeys, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(storage.deletedKeys, isEmpty);

      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(storage.deletedKeys, ['attachments/test-contract.pdf']);
      expect(find.text('合同附件'), findsOneWidget);
      expect(find.text('暂无合同附件'), findsOneWidget);
      expect(
        (await queryService.commercialInsuranceDetail(
          'commercial-1',
        ))!.insurance.attachments,
        isEmpty,
      );
    },
  );

  testWidgets('saves a social insurance form with the selected member', (
    tester,
  ) async {
    await DriftInsuredPersonRepository(
      database,
    ).save(_person('person-1', '张一'));
    await DriftInsuredPersonRepository(
      database,
    ).save(_person('person-2', '张二'));
    final router = _formRouter(
      const SocialInsuranceFormPage(initialInsuredPersonId: 'person-1'),
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('social-insured-person-select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('insured-person-option-person-2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('缴费记录'), findsNothing);
    expect(find.byKey(const ValueKey('social-type-choice')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('social-participant-type-choice')),
      findsOneWidget,
    );
    await tester.tap(find.text('生育'));
    await tester.tap(find.text('居民'));
    await tester.runAsync(() async {
      await loadChinaRegions();
    });
    await tester.tap(find.byKey(const ValueKey('social-region-select')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('region-option-330000')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AppRegionPickerSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.byKey(const ValueKey('region-option-330000')));
    await tester.pumpAndSettle();
    expect(find.text('选择参保地区'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('region-option-330100')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存记录'));
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(find.text('打开表单'), findsOneWidget);
    final records = await DriftSocialInsuranceRepository(database).list();
    expect(records.single.region, '浙江省 / 杭州市');
    expect(records.single.insuredPersonId, 'person-2');
    expect(records.single.insuranceType, SocialInsuranceType.maternity);
    expect(records.single.participantType, SocialParticipantType.resident);
    expect(records.single.contributionRecords, isEmpty);
  });

  testWidgets(
    'edits the social member and region while retaining contributions',
    (tester) async {
      await _seedMembers(database);
      final repository = DriftSocialInsuranceRepository(database);
      final original = (await repository.find('medical-1'))!;
      final router = _formRouter(
        const SocialInsuranceFormPage(insuranceId: 'medical-1'),
      );
      addTearDown(router.dispose);

      await tester.runAsync(() => loadChinaRegions());
      await _pumpRouter(tester, database, queryService, router);
      await tester.tap(find.text('打开表单'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-insured-person-select')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-region-select')),
        findsOneWidget,
      );
      expect(find.text('上海'), findsNothing);
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.text('请选择参保地区'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('social-insured-person-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('insured-person-option-person-2')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => loadChinaRegions());
      await tester.tap(find.byKey(const ValueKey('social-region-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('region-option-110000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('region-option-110100')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存修改'));
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      expect(find.text('打开表单'), findsOneWidget);
      final updated = (await repository.find('medical-1'))!;
      expect(updated.insuredPersonId, 'person-2');
      expect(updated.region, '北京市 / 北京市');
      expect(updated.insuranceType, original.insuranceType);
      expect(updated.participantType, original.participantType);
      expect(updated.createdAt, original.createdAt);
      expect(updated.contributionRecords, hasLength(1));
      expect(updated.contributionRecords.single.period, '2026-01');
      expect(
        updated.contributionRecords.single.contributionBase,
        original.contributionRecords.single.contributionBase,
      );
      expect(updated.contributionRecords.single.contributionAmount, isNull);
    },
  );

  testWidgets('clears a district previously saved as a municipality city', (
    tester,
  ) async {
    await _seedMembers(database, socialRegion: '北京市 / 东城区');
    final router = _formRouter(
      const SocialInsuranceFormPage(insuranceId: 'medical-1'),
    );
    addTearDown(router.dispose);
    await tester.runAsync(() => loadChinaRegions());
    await _pumpRouter(tester, database, queryService, router);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    expect(find.text('北京市 / 东城区'), findsNothing);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.text('请选择参保地区'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('social-region-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-option-110000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-option-110100')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.text('打开表单'), findsOneWidget);
    final updated = (await DriftSocialInsuranceRepository(
      database,
    ).find('medical-1'))!;
    expect(updated.region, '北京市 / 北京市');
    expect(updated.contributionRecords, hasLength(1));
  });

  testWidgets(
    'restores the saved city selection when editing a social member',
    (tester) async {
      await _seedMembers(database, socialRegion: '北京市 / 北京市');
      final router = _formRouter(
        const SocialInsuranceFormPage(insuranceId: 'medical-1'),
      );
      addTearDown(router.dispose);
      await tester.runAsync(() => loadChinaRegions());
      await _pumpRouter(tester, database, queryService, router);
      await tester.tap(find.text('打开表单'));
      await tester.pumpAndSettle();
      expect(find.text('北京市 / 北京市'), findsOneWidget);

      await tester.runAsync(() => loadChinaRegions());
      await tester.tap(find.byKey(const ValueKey('social-region-select')));
      await tester.pumpAndSettle();
      final city = find.byKey(const ValueKey('region-option-110100'));
      expect(city, findsOneWidget);
      expect(tester.widget<ListTile>(city).selected, isTrue);
      expect(find.text('东城区'), findsNothing);
      await tester.tap(find.byTooltip('关闭地区选择'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('social-insured-person-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('insured-person-option-person-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.text('打开表单'), findsOneWidget);
      final updated = (await DriftSocialInsuranceRepository(
        database,
      ).find('medical-1'))!;
      expect(updated.insuredPersonId, 'person-2');
      expect(updated.region, '北京市 / 北京市');
      expect(updated.contributionRecords, hasLength(1));
    },
  );

  testWidgets('manages policy responsibilities from the detail page', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const CommercialInsuranceDetailPage(insuranceId: 'commercial-1'),
        ),
        GoRoute(
          path: '/insurance/commercial/:id/responsibilities',
          builder: (context, state) => CommercialInsuranceResponsibilitiesPage(
            insuranceId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    await tester.tap(
      find.byKey(const ValueKey('commercial-coverage-overview')),
    );
    await tester.pumpAndSettle();
    expect(find.text('保障责任'), findsOneWidget);
    expect(find.text('家庭医疗险'), findsNothing);
    expect(find.text('责任列表'), findsNothing);
    expect(find.text('保存责任'), findsNothing);
    expect(find.byTooltip('新增卡片'), findsOneWidget);
    expect(find.text('住院报销'), findsOneWidget);
    expect(find.byTooltip('新增要点'), findsOneWidget);
    expect(find.byTooltip('编辑卡片'), findsOneWidget);
    expect(find.byTooltip('删除卡片'), findsOneWidget);

    expect(find.byTooltip('编辑保障概要与亮点'), findsNothing);
    for (final (label, inputKey, value) in const [
      ('保障概要', 'coverage-summary-input', '住院医疗保障'),
      ('保障亮点', 'coverage-highlights-input', '包含门诊医疗'),
      ('等待期', 'coverage-waiting-period-input', '疾病30天；意外无等待期'),
      ('除外责任', 'coverage-exclusions-input', '既往症相关责任除外\n特定疾病除外'),
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(inputKey)),
          matching: find.byType(TextField),
        ),
        value,
      );
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
    }
    expect(find.text('住院医疗保障'), findsOneWidget);
    expect(find.text('包含门诊医疗'), findsOneWidget);
    final overview = await queryService.commercialInsuranceDetail(
      'commercial-1',
    );
    expect(overview!.insurance.coverageSummary, '住院医疗保障');
    expect(overview.insurance.coverageHighlights, '包含门诊医疗');
    expect(overview.insurance.waitingPeriodDescription, '疾病30天；意外无等待期');
    expect(overview.insurance.exclusionsDescription, '既往症相关责任除外\n特定疾病除外');
    expect(find.text('既往症约定'), findsNothing);
    expect(find.text('既往症相关责任除外\n特定疾病除外'), findsOneWidget);

    await tester.tap(find.byTooltip('新增要点'));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), '门诊医疗');
    await tester.enterText(find.byType(TextField).at(1), '年度限额 5 万');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('门诊医疗'), findsOneWidget);
    var detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.single.points.map(
        (point) => point.label,
      ),
      contains('门诊医疗'),
    );

    await tester.tap(find.text('门诊医疗'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '年度限额 6 万');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('年度限额 6 万'), findsOneWidget);
    detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.single.points
          .singleWhere((point) => point.label == '门诊医疗')
          .value,
      '年度限额 6 万',
    );

    final pointId = detail.insurance.responsibilities.single.points
        .singleWhere((point) => point.label == '门诊医疗')
        .id;
    expect(find.byTooltip('删除要点'), findsNothing);
    await tester.tap(find.byKey(ValueKey('responsibility-point-$pointId')));
    await tester.pumpAndSettle();
    expect(find.text('编辑要点'), findsOneWidget);
    expect(
      tester.getCenter(find.widgetWithText(TextButton, '删除')).dx,
      lessThan(tester.getCenter(find.widgetWithText(TextButton, '取消')).dx),
    );
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('门诊医疗'), findsNothing);
    detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.single.points.map(
        (point) => point.label,
      ),
      isNot(contains('门诊医疗')),
    );

    await tester.tap(find.byTooltip('新增卡片'));
    await tester.pumpAndSettle();
    expect(find.text('责任要点'), findsNothing);
    await tester.tap(find.text('质子重离子医疗'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('responsibility-description')),
        matching: find.byType(TextField),
      ),
      '  指定医疗机构的质子重离子治疗  ',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('质子重离子医疗'), findsOneWidget);

    detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.map((item) => item.name),
      contains('质子重离子医疗'),
    );
    expect(
      detail.insurance.responsibilities
          .singleWhere((item) => item.name == '质子重离子医疗')
          .points,
      isEmpty,
    );
    expect(
      detail.insurance.responsibilities
          .singleWhere((item) => item.name == '质子重离子医疗')
          .description,
      '指定医疗机构的质子重离子治疗',
    );
    expect(find.text('医疗 · 指定医疗机构的质子重离子治疗'), findsOneWidget);

    final newCard = find.ancestor(
      of: find.text('质子重离子医疗'),
      matching: find.byType(AppSurface),
    );
    await tester.tap(
      find.descendant(of: newCard, matching: find.byTooltip('编辑卡片')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '质子重离子治疗');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('responsibility-description')),
        matching: find.byType(TextField),
      ),
      '  ',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.map((item) => item.name),
      contains('质子重离子治疗'),
    );
    expect(
      detail.insurance.responsibilities
          .singleWhere((item) => item.name == '质子重离子治疗')
          .description,
      isNull,
    );

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('质子重离子治疗'),
          matching: find.byType(AppSurface),
        ),
        matching: find.byTooltip('删除卡片'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    detail = await queryService.commercialInsuranceDetail('commercial-1');
    expect(
      detail!.insurance.responsibilities.map((item) => item.name),
      isNot(contains('质子重离子治疗')),
    );
  });

  testWidgets('responsibility cards fit a phone-width layout', (tester) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const CommercialInsuranceResponsibilitiesPage(
                insuranceId: 'commercial-1',
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

    expect(
      find.byKey(const ValueKey('manage-responsibility-responsibility-1')),
      findsOneWidget,
    );
    expect(find.text('保障责任'), findsOneWidget);
    expect(find.byTooltip('新增卡片'), findsOneWidget);
    expect(find.text('住院报销'), findsOneWidget);
    expect(find.byTooltip('新增要点'), findsOneWidget);
    expect(find.byTooltip('编辑卡片'), findsOneWidget);
    expect(find.byTooltip('删除卡片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a contribution record from social insurance detail', (
    tester,
  ) async {
    await _seedMembers(database);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SocialInsuranceDetailPage(insuranceId: 'medical-1'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, database, queryService, router);

    expect(find.text('1 条'), findsNothing);
    await tester.tap(find.text('缴费'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '添加缴费记录'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('contribution-year-input')),
        matching: find.byType(TextField),
      ),
      '2026',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('contribution-note-input')),
        matching: find.byType(TextField),
      ),
      '年度补缴',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('contribution-amount-input')),
        matching: find.byType(TextField),
      ),
      '9000',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('2 条'), findsNothing);
    final records = await DriftSocialInsuranceRepository(
      database,
    ).find('medical-1');
    expect(find.text('9000'), findsOneWidget);
    expect(find.text('年度补缴'), findsOneWidget);
    expect(records!.contributionRecords, hasLength(2));
    final annual = records.contributionRecords.singleWhere(
      (record) => record.month == null,
    );
    expect(annual.year, 2026);
    expect(annual.contributionBase, isNull);
    expect(annual.contributionAmount?.minorUnits, 900000);
    expect(annual.note, '年度补缴');
    expect(
      tester.getTopLeft(find.text('缴费 · 2026年01月')).dy,
      lessThan(tester.getTopLeft(find.text('缴费 · 2026年')).dy),
    );
  });

  testWidgets(
    'adds, edits and right-swipes a contribution from social detail',
    (tester) async {
      await _seedMembers(database);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const SocialInsuranceDetailPage(insuranceId: 'pension-1'),
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
      final recordsCard = find.byKey(
        const ValueKey('social-contribution-records'),
      );
      expect(recordsCard, findsOneWidget);
      expect(find.text('暂无缴费记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('缴费'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('contribution-year-input')),
          matching: find.byType(TextField),
        ),
        '2026',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('contribution-amount-input')),
          matching: find.byType(TextField),
        ),
        '1000',
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(recordsCard, findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(
        (await DriftSocialInsuranceRepository(
          database,
        ).find('pension-1'))!.contributionRecords,
        hasLength(1),
      );

      final row = find.byKey(const ValueKey('social-contribution-2026'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, '编辑缴费记录'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('contribution-amount-input')),
          matching: find.byType(TextField),
        ),
        '1200',
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('1200'), findsOneWidget);
      expect(
        (await DriftSocialInsuranceRepository(database).find(
          'pension-1',
        ))!.contributionRecords.single.contributionAmount?.minorUnits,
        120000,
      );
      expect(find.byTooltip('编辑缴费记录'), findsNothing);
      expect(find.byTooltip('删除缴费记录'), findsNothing);

      await tester.drag(row, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, '删除缴费记录'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(
        (await DriftSocialInsuranceRepository(
          database,
        ).find('pension-1'))!.contributionRecords,
        hasLength(1),
      );
      await tester.drag(row, const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      expect(recordsCard, findsOneWidget);
      expect(find.text('暂无缴费记录'), findsOneWidget);
      expect(find.text('缴费'), findsOneWidget);
      expect(
        (await DriftSocialInsuranceRepository(
          database,
        ).find('pension-1'))!.contributionRecords,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
    int rowPosition(Finder row, String label) {
      final text = find.descendant(of: row, matching: find.text(label));
      return (tester.getTopLeft(text).dy * 10).round();
    }

    const categoryLabels = ['医疗', '重疾', '意外', '寿险', '其他'];
    final categoryRows = {
      for (final label in categoryLabels) rowPosition(categoryRow, label),
    };
    expect(categoryRows, hasLength(1));

    expect(
      find.byKey(const ValueKey('commercial-premium-frequency-choice')),
      findsNothing,
    );
    expect(find.text('期缴金额'), findsNothing);
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
    for (final (key, text) in const [
      ('commercial-policyholder', '示例公司'),
      ('commercial-beneficiary', '姓名、法定或其他合同约定'),
    ]) {
      final field = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }
    expect(find.text('保额说明'), findsNothing);
    expect(find.text('保障期间与保额'), findsNothing);
    expect(find.text('合同信息'), findsOneWidget);
    expect(find.text('等待期'), findsNothing);
    expect(find.text('既往症约定'), findsNothing);
    expect(find.text('除外责任'), findsNothing);
    expect(find.text('缴费说明'), findsNothing);
    expect(find.text('保障责任'), findsNothing);
    expect(find.text('缴费期数'), findsNothing);
    expect(find.text('期缴金额'), findsNothing);
    expect(find.textContaining('张一 · 其他 ·'), findsOneWidget);
    expect(
      find.byType(AppPlainChoiceChipFormRow<CommercialInsuranceCategory>),
      findsOneWidget,
    );
    expect(
      find.byType(AppPlainChoiceChipFormRow<PremiumFrequency>),
      findsNothing,
    );
    await tester.ensureVisible(find.text('意外'));
    await tester.tap(find.text('意外'));
    await tester.tap(find.byKey(const ValueKey('commercial-form-save')));
    await tester.pumpAndSettle();

    expect(find.text('打开表单'), findsOneWidget);
    final records = await DriftCommercialInsuranceRepository(
      database,
    ).list(insuredPersonId: 'person-1');
    expect(records.single.name, '百万医疗');
    expect(records.single.policyholderName, '示例公司');
    expect(records.single.beneficiaryDescription, '姓名、法定或其他合同约定');
    expect(records.single.waitingPeriodDescription, isNull);
    expect(records.single.exclusionsDescription, isNull);
    expect(records.single.coverageAmountDescription, isNull);
    expect(records.single.insuredPersonIds, ['person-1']);
    expect(records.single.category, CommercialInsuranceCategory.accident);
    expect(records.single.premiumPlan, isNull);
  });

  testWidgets(
    'contract information displays and edits as free text on a phone',
    (tester) async {
      await _seedMembers(database);
      final repository = DriftCommercialInsuranceRepository(database);
      final original = (await repository.find('commercial-1'))!;
      await repository.save(
        CommercialInsurance(
          id: original.id,
          name: original.name,
          insurerName: original.insurerName,
          category: original.category,
          coverageTerm: original.coverageTerm,
          coverageAmount: original.coverageAmount,
          insuredPersonIds: original.insuredPersonIds,
          responsibilities: original.responsibilities,
          attachments: original.attachments,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
          policyholderName: '示例公司',
          beneficiaryDescription: '姓名、法定或其他给付约定',
          waitingPeriodDescription: '疾病30天；意外无等待期',
          exclusionsDescription: '本保单承保约定\n特别除外约定',
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CommercialInsuranceDetailPage(
              insuranceId: 'commercial-1',
            ),
          ),
          GoRoute(
            path: '/insurance/commercial/:id/edit',
            builder: (context, state) => CommercialInsuranceFormPage(
              insuranceId: state.pathParameters['id'],
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
        size: const Size(360, 844),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('commercial-overview-card')),
      );
      expect(find.text('受益人 姓名、法定或其他给付约定'), findsOneWidget);
      expect(find.text('身故受益人'), findsNothing);
      expect(find.text('投保人 示例公司'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('commercial-coverage-overview')),
          matching: find.text('等待期'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('commercial-contract-info')),
        findsNothing,
      );
      expect(find.text('本保单承保约定\n特别除外约定'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑商业保险'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      for (final (key, value) in const [
        ('commercial-policyholder', '示例公司'),
        ('commercial-beneficiary', '姓名、法定或其他给付约定'),
      ]) {
        final field = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextField),
        );
        await tester.dragUntilVisible(
          field,
          find.byType(ListView),
          const Offset(0, -200),
        );
        expect(tester.widget<TextField>(field).controller!.text, value);
      }
      final beneficiary = find.descendant(
        of: find.byKey(const ValueKey('commercial-beneficiary')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(beneficiary);
      await tester.enterText(beneficiary, '');
      expect(find.text('等待期'), findsNothing);
      expect(find.text('既往症约定'), findsNothing);
      expect(find.text('除外责任'), findsNothing);
      expect(find.text('保存修改'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commercial-form-save')));
      await tester.pumpAndSettle();
      final saved = (await repository.find('commercial-1'))!;
      expect(saved.beneficiaryDescription, isNull);
      expect(saved.policyholderName, '示例公司');
      expect(saved.waitingPeriodDescription, '疾病30天；意外无等待期');
      expect(saved.exclusionsDescription, '本保单承保约定\n特别除外约定');
      expect(saved.responsibilities.single.points.single.label, '住院报销');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long presses reorder responsibility cards and points independently',
    (tester) async {
      await _seedMembers(database);
      final repository = DriftCommercialInsuranceRepository(database);
      final original = (await repository.find('commercial-1'))!;
      await repository.save(
        CommercialInsurance(
          id: original.id,
          name: original.name,
          insurerName: original.insurerName,
          category: original.category,
          coverageTerm: original.coverageTerm,
          coverageAmount: original.coverageAmount,
          insuredPersonIds: original.insuredPersonIds,
          responsibilities: [
            CoverageResponsibility(
              id: 'a',
              kind: ResponsibilityKind.medical,
              name: '责任甲',
              order: 0,
              points: const [
                ResponsibilityPoint(
                  id: 'p1',
                  label: '条款一',
                  value: '内容一',
                  order: 0,
                ),
                ResponsibilityPoint(
                  id: 'p2',
                  label: '条款二',
                  value: '内容二',
                  order: 1,
                ),
              ],
            ),
            CoverageResponsibility(
              id: 'b',
              kind: ResponsibilityKind.death,
              name: '责任乙',
              order: 1,
              points: const [],
            ),
          ],
          attachments: original.attachments,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const CommercialInsuranceResponsibilitiesPage(
                  insuranceId: 'commercial-1',
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
      final filter = find.byKey(const ValueKey('responsibility-kind-filter'));
      expect(
        find.descendant(of: filter, matching: find.text('疾病给付')),
        findsNothing,
      );
      await tester.tap(find.descendant(of: filter, matching: find.text('医疗')));
      await tester.pumpAndSettle();
      expect(find.text('责任乙'), findsNothing);
      await tester.tap(find.descendant(of: filter, matching: find.text('全部')));
      await tester.pumpAndSettle();

      final point = find.byKey(const ValueKey('responsibility-point-p1'));
      final pointHeight = tester.getSize(point).height;
      final pointGesture = await tester.startGesture(tester.getCenter(point));
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 0; step < 10; step++) {
        await pointGesture.moveBy(Offset(0, pointHeight * 1.2 / 10));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await pointGesture.up();
      await tester.pumpAndSettle();
      var saved = (await repository.find('commercial-1'))!;
      expect(saved.responsibilities.first.points.map((item) => item.id), [
        'p2',
        'p1',
      ]);
      expect(find.byType(AlertDialog), findsNothing);

      final firstTitle = find.text('责任甲');
      final secondTitle = find.text('责任乙');
      final distance =
          tester.getCenter(secondTitle).dy - tester.getCenter(firstTitle).dy;
      final cardGesture = await tester.startGesture(
        tester.getCenter(firstTitle),
      );
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 0; step < 10; step++) {
        await cardGesture.moveBy(
          Offset(0, (distance + AppSpacing.space20) / 10),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await cardGesture.up();
      await tester.pumpAndSettle();
      saved = (await repository.find('commercial-1'))!;
      expect(saved.responsibilities.map((item) => item.id), ['b', 'a']);
      expect(saved.responsibilities.last.points.map((item) => item.id), [
        'p2',
        'p1',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'payment configuration saves independently from the policy form',
    (tester) async {
      await _seedMembers(database);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CommercialInsuranceDetailPage(
              insuranceId: 'commercial-1',
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
      final repository = DriftCommercialInsuranceRepository(database);
      final original = (await repository.find('commercial-1'))!;

      await tester.tap(find.text('缴费配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('年缴'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await repository.find('commercial-1'))!.premiumPlan, isNull);

      await tester.tap(find.text('缴费配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('年缴'));
      final terms = find.descendant(
        of: find.byKey(const ValueKey('commercial-premium-term-count')),
        matching: find.byType(TextField),
      );
      final amount = find.descendant(
        of: find.byKey(const ValueKey('commercial-premium-amount')),
        matching: find.byType(TextField),
      );
      await tester.enterText(terms, '0');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入正整数'), findsOneWidget);
      expect((await repository.find('commercial-1'))!.premiumPlan, isNull);
      await tester.enterText(terms, '20');
      await tester.enterText(amount, '1200');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      var saved = (await repository.find('commercial-1'))!;
      expect(saved.premiumPlan?.frequency, PremiumFrequency.annual);
      expect(saved.premiumPlan?.termCount, 20);
      expect(saved.premiumPlan?.amount?.minorUnits, 120000);
      expect(saved.coverageAmount?.amount, original.coverageAmount?.amount);
      expect(
        saved.responsibilities.single.id,
        original.responsibilities.single.id,
      );
      expect(saved.insuredPersonIds, original.insuredPersonIds);

      await tester.tap(find.text('缴费配置'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(terms).controller!.text, '20');
      expect(tester.widget<TextField>(amount).controller!.text, '1200');
      await tester.tap(find.text('月缴'));
      await tester.enterText(terms, '');
      await tester.enterText(amount, '');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      saved = (await repository.find('commercial-1'))!;
      expect(saved.premiumPlan?.frequency, PremiumFrequency.monthly);
      expect(saved.premiumPlan?.termCount, isNull);
      expect(saved.premiumPlan?.amount, isNull);

      await tester.tap(find.text('缴费配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除配置'));
      await tester.pumpAndSettle();
      expect((await repository.find('commercial-1'))!.premiumPlan, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('insurance detail cards fit narrow screens and large text', (
    tester,
  ) async {
    await _seedMembers(
      database,
      socialRegion: '内蒙古自治区 / 呼和浩特市',
      productForm: '长期医疗（住院与特殊门诊保障）',
      commercialInsuredPersonIds: const ['person-1', 'person-2'],
    );
    for (final page in const [
      CommercialInsuranceDetailPage(insuranceId: 'commercial-1'),
      SocialInsuranceDetailPage(insuranceId: 'medical-1'),
    ]) {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (context, state) => page)],
      );
      addTearDown(router.dispose);
      await _pumpRouter(
        tester,
        database,
        queryService,
        router,
        size: const Size(320, 844),
        textScaler: const TextScaler.linear(1.8),
      );
      expect(tester.takeException(), isNull);
      if (page is CommercialInsuranceDetailPage) {
        expect(find.text('家庭医疗险 · 长期医疗（住院与特殊门诊保障）'), findsOneWidget);
        expect(find.text('张一、张二'), findsOneWidget);
      } else {
        expect(find.text('内蒙古自治区 / 呼和浩特市'), findsOneWidget);
        expect(find.text('参保类型'), findsNothing);
      }
    }
  });
}

Future<void> _pumpRouter(
  WidgetTester tester,
  AppDatabase database,
  InsuranceCoverageQueryServiceImpl queryService,
  GoRouter router, {
  Size size = const Size(1080, 2200),
  InsuranceAttachmentStorage? attachmentStorage,
  TextScaler textScaler = TextScaler.noScaling,
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
        if (attachmentStorage != null)
          insuranceAttachmentStorageProvider.overrideWithValue(
            attachmentStorage,
          ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
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

Future<void> _seedMembers(
  AppDatabase database, {
  String socialRegion = '上海',
  String? productForm,
  List<String> commercialInsuredPersonIds = const ['person-1'],
}) async {
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
      productForm: productForm,
      coverageTerm: CoverageTerm(
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2026, 12, 31),
      ),
      coverageAmount: CoverageAmount(amount: Money(minorUnits: 10000000)),
      insuredPersonIds: commercialInsuredPersonIds,
      responsibilities: [
        CoverageResponsibility(
          id: 'responsibility-1',
          kind: ResponsibilityKind.medical,
          name: '住院医疗',
          description: '覆盖合同约定的住院、特殊门诊和门诊手术医疗费用',
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
  await social.save(
    SocialInsurance(
      id: 'medical-1',
      insuredPersonId: 'person-1',
      region: socialRegion,
      insuranceType: SocialInsuranceType.medical,
      participantType: SocialParticipantType.employee,
      contributionRecords: [
        SocialContributionRecord(
          year: 2026,
          month: 1,
          contributionBase: Money(minorUnits: 800000),
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  await social.save(
    SocialInsurance(
      id: 'pension-1',
      insuredPersonId: 'person-1',
      region: socialRegion,
      insuranceType: SocialInsuranceType.pension,
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

class _TestAttachmentStorage implements InsuranceAttachmentStorage {
  final openedKeys = <String>[];
  final deletedKeys = <String>[];

  @override
  Future<List<InsuranceAttachmentDraft>> pickAndStore({
    required String commercialInsuranceId,
  }) async => const [
    InsuranceAttachmentDraft(
      fileName: '合同.pdf',
      storageKey: 'attachments/test-contract.pdf',
      mimeType: 'application/pdf',
    ),
  ];

  @override
  Future<void> open(String storageKey) async => openedKeys.add(storageKey);

  @override
  Future<void> delete(String storageKey) async => deletedKeys.add(storageKey);
}
