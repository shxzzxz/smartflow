import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/intake/rules/port/recognition_rule_repository.dart';
import 'package:smartflow/domain/intake/rules/port/recognition_rule_target_query.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_configuration.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_plain_text_area_form_row.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_switch.dart';
import 'package:smartflow/design_system/widget/app_tab_swipe_region.dart';
import 'package:smartflow/feature/recognition_rules/page/recognition_rules_page.dart';
import 'package:smartflow/feature/recognition_rules/page/recognition_rule_editor_page.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  final builtins = RecognitionRuleCatalog(
    rules: [
      RecognitionRule(
        id: 'builtin-tea',
        kind: RecognitionRuleKind.category,
        keywords: const ['奶茶', '咖啡'],
        priority: 5,
        targetPath: const ['食品餐饮', '茶饮'],
        targetCategoryKind: ImportCategoryKind.expense,
        isBuiltin: true,
      ),
    ],
  );
  final accounts = [
    RecognitionRule(
      id: 'account-a',
      kind: RecognitionRuleKind.account,
      keywords: const ['第一', '较长的关键词', '第三个关键词', '第四个关键词'],
      priority: 3,
      targetAccountId: 'wallet',
      targetPath: const ['日常付款'],
    ),
    RecognitionRule(
      id: 'account-b',
      kind: RecognitionRuleKind.account,
      keywords: const ['第二'],
      priority: 2,
      targetAccountId: 'wallet',
      targetPath: const ['日常付款'],
    ),
    RecognitionRule(
      id: 'account-c',
      kind: RecognitionRuleKind.account,
      keywords: const ['第三'],
      priority: 1,
      targetAccountId: 'wallet',
      targetPath: const ['日常付款'],
    ),
  ];

  Future<_Repository> open(
    WidgetTester tester, {
    double width = 400,
    TextScaler textScaler = TextScaler.noScaling,
    List<RecognitionRule>? initialRules,
  }) async {
    tester.view.physicalSize = Size(width, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(initialRules ?? accounts);
    final service = RecognitionRulesAppService(
      builtins: builtins,
      repository: repository,
      targets: _Targets(),
      transactions: _Transactions(),
      ids: SequentialIdGenerator(prefix: 'user-rule'),
    );
    final router = GoRouter(
      initialLocation: '/rules',
      routes: [
        GoRoute(
          path: '/rules',
          builder: (_, _) => const RecognitionRulesPage(),
        ),
        GoRoute(
          path: '/profile/recognition-rules/new',
          builder: (_, state) => RecognitionRuleEditorPage(
            initialKind: state.uri.queryParameters['kind'] == 'category'
                ? RecognitionRuleKind.category
                : RecognitionRuleKind.account,
          ),
        ),
        GoRoute(
          path: '/profile/recognition-rules/rule/:id',
          builder: (_, state) =>
              RecognitionRuleEditorPage(ruleId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recognitionRulesAppServiceProvider.overrideWithValue(service),
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
    return repository;
  }

  Future<void> more(WidgetTester tester, String id) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(TextField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'two-line rows and four menu actions fit narrow screens with larger text',
    (tester) async {
      await open(tester, width: 320, textScaler: const TextScaler.linear(1.5));
      final header = find.byType(AppPageHeader);
      for (final label in ['账户规则', '分类规则']) {
        final tab = find.descendant(of: header, matching: find.text(label));
        expect(tab, findsOneWidget);
        final headerBounds = tester.getRect(header);
        final tabBounds = tester.getRect(tab);
        expect(headerBounds.contains(tabBounds.topLeft), isTrue);
        expect(headerBounds.contains(tabBounds.bottomRight), isTrue);
      }
      expect(find.byType(TabBar), findsNothing);
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('account-a')),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(texts, hasLength(2));
      expect(texts.every((text) => text.maxLines == 1), isTrue);
      expect(texts.first.data, accounts.first.keywords.join('、'));
      expect(texts.last.data, '日常付款 · 全部来源');
      expect(find.byType(AppSwitch), findsNothing);
      expect(find.textContaining('优先级'), findsNothing);
      expect(find.textContaining('按列表从上到下识别'), findsNothing);
      await more(tester, 'account-a');
      for (final label in ['置顶', '禁用', '编辑', '删除']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('恢复默认'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account rules start empty without builtin account defaults', (
    tester,
  ) async {
    await open(tester, initialRules: const []);
    expect(find.text('暂无识别规则'), findsOneWidget);
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
  });

  testWidgets('search matches keywords and target paths across tabs', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.getTopLeft(find.byType(SearchBar)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppPageHeader)).dy),
    );
    await search(tester, '关键词');
    expect(find.byKey(const ValueKey('account-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-b')), findsNothing);
    expect(find.byKey(const ValueKey('account-c')), findsNothing);

    await search(tester, ' 付款 ');
    for (final rule in accounts) {
      expect(find.byKey(ValueKey(rule.id)), findsOneWidget);
    }

    await search(tester, '食品');
    expect(find.text('没有找到相关规则'), findsOneWidget);
    expect(find.text('暂无识别规则'), findsNothing);
    final region = tester.getRect(
      find.byType(AppTabSwipeRegion<RecognitionRuleKind>),
    );
    await tester.dragFrom(
      Offset(region.right - 8, region.top + 100),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSlidingSegmentedControl<RecognitionRuleKind>>(
            find.byType(AppSlidingSegmentedControl<RecognitionRuleKind>),
          )
          .selected,
      RecognitionRuleKind.category,
    );
    expect(find.byKey(const ValueKey('builtin-tea')), findsOneWidget);
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      '食品',
    );
    for (final query in ['茶饮', '食品餐饮 / 茶饮', '咖啡']) {
      await search(tester, query);
      expect(find.byKey(const ValueKey('builtin-tea')), findsOneWidget);
    }
    for (final query in ['付款', '第二', '全部来源']) {
      await search(tester, query);
      expect(find.text('没有找到相关规则'), findsOneWidget);
      expect(find.byKey(const ValueKey('builtin-tea')), findsNothing);
    }

    await search(tester, '不存在的规则');
    expect(find.text('没有找到相关规则'), findsOneWidget);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      isEmpty,
    );
    expect(find.byTooltip('清除搜索'), findsNothing);
    expect(find.byKey(const ValueKey('builtin-tea')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search uses current names and includes unavailable disabled rules',
    (tester) async {
      await open(
        tester,
        initialRules: [
          accounts.first.copyWith(
            keywords: const ['Visa'],
            targetPath: const ['旧钱包'],
          ),
          RecognitionRule(
            id: 'unavailable',
            kind: RecognitionRuleKind.account,
            keywords: const ['现金'],
            priority: 0,
            targetAccountId: 'removed',
            targetPath: const ['备用账户'],
            enabled: false,
          ),
        ],
      );
      for (final query in ['  VISA  ', '付款']) {
        await search(tester, query);
        expect(find.byKey(const ValueKey('account-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('unavailable')), findsNothing);
      }
      await search(tester, '旧钱包');
      expect(find.text('没有找到相关规则'), findsOneWidget);
      await search(tester, '备用');
      expect(find.byKey(const ValueKey('unavailable')), findsOneWidget);
      expect(find.textContaining('已禁用'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('filtered actions preserve search and reorder the full list', (
    tester,
  ) async {
    final repository = await open(tester);
    final originalOrder = repository.configuration.order;
    await search(tester, '第三');
    expect(find.byKey(const ValueKey('account-b')), findsNothing);
    final from = tester.getCenter(find.byKey(const ValueKey('account-c')));
    final to = tester.getCenter(find.byKey(const ValueKey('account-a')));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.configuration.order, originalOrder);

    await search(tester, '第二');
    await more(tester, 'account-b');
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(
      repository.configuration.order!
          .where((id) => id.startsWith('account-'))
          .toList(),
      ['account-b', 'account-a', 'account-c'],
    );
    await more(tester, 'account-b');
    await tester.tap(find.text('禁用'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
      '第二',
    );
    expect(find.byKey(const ValueKey('account-a')), findsNothing);
    expect(find.byKey(const ValueKey('account-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-c')), findsNothing);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    for (final rule in accounts) {
      expect(find.byKey(ValueKey(rule.id)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press dragging persists arbitrary ordering', (
    tester,
  ) async {
    final repository = await open(tester);
    final from = tester.getCenter(find.byKey(const ValueKey('account-c')));
    final to = tester.getCenter(find.byKey(const ValueKey('account-a')));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.moveTo(Offset(from.dx, to.dy));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      repository.configuration.order!
          .where((id) => id.startsWith('account-'))
          .toList(),
      ['account-c', 'account-a', 'account-b'],
    );
    final downward = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('account-c'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await downward.moveBy(const Offset(0, 270));
    await tester.pump(const Duration(milliseconds: 400));
    await downward.up();
    await tester.pumpAndSettle();
    expect(
      repository.configuration.order!
          .where((id) => id.startsWith('account-'))
          .toList(),
      ['account-a', 'account-b', 'account-c'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('move to top and enable-disable actions keep the rule in place', (
    tester,
  ) async {
    final repository = await open(tester);
    await more(tester, 'account-b');
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    final order = repository.configuration.order!;
    expect(order.where((id) => id.startsWith('account-')).first, 'account-b');
    await more(tester, 'account-b');
    await tester.tap(find.text('禁用'));
    await tester.pumpAndSettle();
    expect(
      repository.configuration.overrides
          .firstWhere((rule) => rule.id == 'account-b')
          .enabled,
      isFalse,
    );
    expect(repository.configuration.order, order);
    expect(find.textContaining('已禁用'), findsOneWidget);
    await more(tester, 'account-b');
    expect(find.text('启用'), findsOneWidget);
    await tester.tap(find.text('启用'));
    await tester.pumpAndSettle();
    expect(
      repository.configuration.overrides
          .firstWhere((rule) => rule.id == 'account-b')
          .enabled,
      isTrue,
    );
    expect(find.textContaining('已禁用'), findsNothing);
  });

  testWidgets(
    'builtin categories can be edited and deleted through the same menu',
    (tester) async {
      final repository = await open(tester, initialRules: const []);
      await tester.tap(find.text('分类规则'));
      await tester.pumpAndSettle();
      await more(tester, 'builtin-tea');
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AppPlainTextAreaFormRow),
          matching: find.byType(TextField),
        ),
        '我的咖啡店',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(repository.configuration.overrides.single.keywords, ['我的咖啡店']);
      await more(tester, 'builtin-tea');
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      expect(repository.configuration.deletedRuleIds, contains('builtin-tea'));
      expect(find.byKey(const ValueKey('builtin-tea')), findsNothing);
      expect(find.text('暂无识别规则'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new account rules select an existing target and start first', (
    tester,
  ) async {
    final repository = await open(tester, initialRules: const []);
    await tester.tap(find.byTooltip('新增识别规则'));
    await tester.pumpAndSettle();
    expect(find.text('规则名称'), findsNothing);
    expect(find.text('收支方向'), findsNothing);
    expect(find.textContaining('优先级'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppPlainTextAreaFormRow),
        matching: find.byType(TextField),
      ),
      '6620',
    );
    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常付款'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final rule = repository.configuration.overrides.single;
    expect(rule.targetAccountId, 'wallet');
    expect(rule.keywords, ['6620']);
    expect(repository.configuration.order!.first, rule.id);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements RecognitionRuleRepository {
  _Repository(List<RecognitionRule> rules)
    : configuration = RecognitionRuleConfiguration(overrides: rules);
  RecognitionRuleConfiguration configuration;
  @override
  Future<RecognitionRuleConfiguration> loadConfiguration() async =>
      configuration;
  @override
  Future<void> saveConfiguration(RecognitionRuleConfiguration value) async {
    configuration = value;
  }
}

class _Targets implements RecognitionRuleTargetQuery {
  @override
  Future<List<RecognitionRuleTarget>> findAvailableTargets() async => [
    RecognitionRuleTarget(
      id: 'wallet',
      kind: RecognitionRuleKind.account,
      path: ['日常付款'],
      profileKey: 'ledger.fund',
    ),
    RecognitionRuleTarget(
      id: 'food',
      kind: RecognitionRuleKind.category,
      path: ['食品餐饮'],
      direction: ImportCategoryKind.expense,
    ),
    RecognitionRuleTarget(
      id: 'drinks',
      kind: RecognitionRuleKind.category,
      path: ['食品餐饮', '茶饮'],
      direction: ImportCategoryKind.expense,
    ),
    RecognitionRuleTarget(
      id: 'salary',
      kind: RecognitionRuleKind.category,
      path: ['工作', '工资'],
      direction: ImportCategoryKind.income,
    ),
  ];
}

class _Transactions implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
