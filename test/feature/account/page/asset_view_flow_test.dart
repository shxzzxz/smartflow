// The harness isolates each flow by overriding app-wide providers in its test scope.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/application/analytics/analytics_command_api.dart';
import 'package:smartflow/feature/account/page/account_form_page.dart';
import 'package:smartflow/feature/account/presentation/account_creation_presets.dart';
import 'package:smartflow/feature/account/view_model/asset_views_provider.dart';
import 'package:smartflow/feature/account/widget/asset_account_sections.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/asset_section_collapse_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_header_select_button.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';
import 'package:smartflow/feature/account/page/accounts_page.dart';
import 'package:smartflow/feature/account/page/asset_view_form_page.dart';
import 'package:smartflow/feature/account/page/asset_views_page.dart';
import 'package:smartflow/feature/account/presentation/asset_view_presentation.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/account/widget/asset_summary_card.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import '../../../helper/asset_view_dependencies.dart';
import '../../../helper/book_selection_override.dart';

void main() {
  testWidgets(
    'type filtering keeps full-view statistics and all groups use list cards',
    (tester) async {
      final view = _daily('daily', '日常视图');
      final harness = _Harness(views: [view], selected: view.id);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byType(AccountSectionCard), findsNWidgets(2));
      expect(find.text('账户A'), findsOneWidget);
      expect(find.text('信用账户B'), findsOneWidget);
      expect(find.text('范围外账户'), findsNothing);
      await tester.tap(_type('资产'));
      await tester.pumpAndSettle();
      final statistics = tester
          .widget<AssetSummaryCard>(find.byType(AssetSummaryCard))
          .statistics;
      expect(statistics.assets.minorUnits, 10000);
      expect(statistics.liabilities.minorUnits, 5000);
      expect(find.byType(AccountSectionCard), findsOneWidget);
      expect(find.text('账户A'), findsOneWidget);
      expect(find.text('信用账户B'), findsNothing);
    },
  );

  testWidgets(
    'name and accounts create a profile-grouped view and reset the filter to all',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(_type('资产'));
      await tester.pumpAndSettle();
      await _newView(tester, '负债视图', ['信用账户B']);
      expect(find.text('展示布局'), findsNothing);
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      expect(find.text('负债视图'), findsOneWidget);
      expect(find.text('信用账户B'), findsOneWidget);
      expect(find.text('账户A'), findsNothing);
      expect(
        tester
            .widget<AppSlidingSegmentedControl<AssetAccountFilter>>(
              find.byType(AppSlidingSegmentedControl<AssetAccountFilter>),
            )
            .selected,
        AssetAccountFilter.all,
      );
      expect(harness.commands.savedCommands.single.accountIds, ['debt']);
      final saved = (await harness.queries.findView('created-view-1'))!;
      expect(
        saved.groupIdFor('debt'),
        saved.groups.firstWhere((group) => group.name == '信用').id,
      );
      expect(harness.preferences.selected, saved.id);
    },
  );

  testWidgets(
    'preview uses draft scope and list cards until the view is created',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await _newView(tester, '预览视图', ['账户A', '信用账户B']);
      await tester.tap(find.byTooltip('预览视图'));
      await tester.pumpAndSettle();
      expect(find.text('预览 · 预览视图'), findsOneWidget);
      expect(find.byType(AccountSectionCard), findsNWidgets(2));
      expect(find.text('账户A'), findsOneWidget);
      expect(find.text('范围外账户'), findsNothing);
      expect(harness.commands.savedCommands, isEmpty);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      expect(harness.commands.savedCommands.single.accountIds.toSet(), {
        'cash',
        'debt',
      });
      expect(find.text('预览视图'), findsOneWidget);
    },
  );

  testWidgets('saving failure keeps name and scope for retry', (tester) async {
    final harness = _Harness()..commands.failSave = true;
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await _newView(tester, '保留输入', ['账户A']);
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('测试保存失败'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留输入',
    );
    expect(harness.commands.savedCommands.single.accountIds, ['cash']);
    harness.commands.failSave = false;
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('保留输入'), findsOneWidget);
  });

  testWidgets('copying preserves independent scope group names and order', (
    tester,
  ) async {
    final original = AssetView(
      id: 'original',
      name: '日常',
      accountIds: ['cash', 'debt'],
      groups: [
        AssetViewGroup(id: 'credit', name: '借贷'),
        AssetViewGroup(id: 'fund', name: '资金'),
      ],
      accountGroupIds: {'cash': 'fund', 'debt': 'credit'},
    );
    final harness = _Harness(views: [original], selected: original.id);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理视图'));
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('日常'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('视图操作')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制视图'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '日常 副本',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    final copied = (await harness.queries.findView('created-view-1'))!;
    expect(copied.accountIds, original.accountIds);
    expect(copied.accountGroupIds, original.accountGroupIds);
    expect(copied.groups.map((group) => group.name), ['借贷', '资金']);
    await harness.commands.renameGroup(copied.id, 'credit', '副本负债');
    expect(
      (await harness.queries.findView(original.id))!.groups.first.name,
      '借贷',
    );
  });

  testWidgets('default view lets the user edit its account scope', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.text('包含账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('范围外账户'));
    await tester.tap(find.text('信用账户B'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('账户A'), findsOneWidget);
    expect(find.text('范围外账户'), findsNothing);
    expect(find.text('信用账户B'), findsNothing);
    expect((await harness.queries.findView(AssetView.defaultId))!.accountIds, [
      'cash',
    ]);
  });

  testWidgets(
    'new account chooses selected-view groups and joins only that view',
    (tester) async {
      final view = AssetView(
        id: 'private',
        name: '日常',
        accountIds: ['cash'],
        groups: [AssetViewGroup(id: 'private-group', name: '仅此视图')],
        accountGroupIds: {'cash': 'private-group'},
      );
      final harness = _Harness(views: [view], selected: view.id);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支付宝'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('账户分组'));
      await tester.pumpAndSettle();
      expect(find.text('仅此视图'), findsOneWidget);
      expect(find.widgetWithText(ListTile, '信用'), findsNothing);
      await tester.tap(find.text('仅此视图'));
      await tester.pumpAndSettle();
      final name = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((field) => field.controller?.text == '支付宝');
      await tester.enterText(find.byWidget(name), '新账户');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final command = harness.accountCommands.created.single;
      expect(command.viewId, view.id);
      expect(command.groupId, 'private-group');
      expect(command.account.name, '新账户');
      expect(harness.router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('新账户'), findsOneWidget);
      await tester.tap(find.text('日常'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认'));
      await tester.pumpAndSettle();
      expect(find.text('新账户'), findsNothing);
    },
  );

  testWidgets(
    'group manager keeps its original view when selection changes while open',
    (tester) async {
      final view = _daily('daily', '日常');
      final harness = _Harness(views: [view], selected: view.id);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountsPage)),
      );
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理分组'));
      await tester.pumpAndSettle();
      await container
          .read(assetViewSelectionViewModelProvider.notifier)
          .selectView(AssetView.defaultId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建分组'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '视图内新组');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(harness.commands.createdGroups.single.viewId, view.id);
      expect(
        (await harness.queries.findView(
          AssetView.defaultId,
        ))!.groups.any((group) => group.name == '视图内新组'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting the selected view returns to default', (tester) async {
    final selected = _daily('delete-me', '待删除');
    final harness = _Harness(views: [selected], selected: selected.id);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理视图'));
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('待删除'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('视图操作')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('待删除'), findsNothing);
    expect(find.text('范围外账户'), findsOneWidget);
  });

  testWidgets('filters stay centered when adapting and retain the selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final view = _daily('daily', '日常收支与长期规划资产视图');
    final harness = _Harness(views: [view], selected: view.id);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    _expectHeaderCentered(tester);
    expect(
      find.byType(AppHeaderSelectButton<AssetAccountFilter>),
      findsNothing,
    );

    await tester.tap(_type('资产'));
    await tester.pumpAndSettle();
    final dropdown = find.byType(AppHeaderSelectButton<AssetAccountFilter>);
    for (final width in [390.0, 360.0, 320.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      _expectHeaderCentered(tester);
      expect(
        tester
            .widget<AppHeaderSelectButton<AssetAccountFilter>>(dropdown)
            .value,
        AssetAccountFilter.asset,
      );
    }
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('负债'), matching: find.byType(MenuItemButton)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('信用账户B'), findsOneWidget);
    expect(find.text('账户A'), findsNothing);

    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpAndSettle();
    _expectHeaderCentered(tester);
    expect(
      find.byType(AppHeaderSelectButton<AssetAccountFilter>),
      findsNothing,
    );
    expect(
      tester
          .widget<AppSlidingSegmentedControl<AssetAccountFilter>>(
            find.byType(AppSlidingSegmentedControl<AssetAccountFilter>),
          )
          .selected,
      AssetAccountFilter.liability,
    );
    expect(find.text('信用账户B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('view menu opens management and closes before navigation', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换视图：默认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    expect(find.byType(AssetViewsPage), findsOneWidget);
    expect(find.text('管理'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换视图：默认'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 500));
    await tester.pumpAndSettle();
    expect(find.text('新建'), findsNothing);
    expect(harness.router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets(
    'view menu anchors below a centered header at 320px with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final view = _daily('long-view', '日常收支与长期规划资产视图');
      final harness = _Harness(views: [view], selected: view.id);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app(textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectHeaderCentered(tester);
      expect(
        find.byType(AppHeaderSelectButton<AssetAccountFilter>),
        findsOneWidget,
      );
      final trigger = tester.getRect(find.byTooltip('切换视图：${view.name}'));
      await tester.tap(find.byTooltip('切换视图：${view.name}'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final firstOption = tester.getRect(find.byType(MenuItemButton).first);
      expect(firstOption.left, moreOrLessEquals(trigger.left));
      expect(firstOption.top, greaterThanOrEqualTo(trigger.bottom));
      final currentOption = find.ancestor(
        of: find.text(view.name),
        matching: find.byType(MenuItemButton),
      );
      expect(
        find.descendant(
          of: currentOption,
          matching: find.byIcon(RemixIcons.check_line),
        ),
        findsOneWidget,
      );
      expect(find.text('默认'), findsOneWidget);
      expect(find.text('新建'), findsOneWidget);
      await tester.tap(find.text('默认'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(harness.preferences.selected, AssetView.defaultId);
      _expectHeaderCentered(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

AssetView _daily(String id, String name) => AssetView(
  id: id,
  name: name,
  accountIds: ['cash', 'debt'],
  groups: [
    AssetViewGroup(id: 'fund', name: '资金'),
    AssetViewGroup(id: 'credit', name: '信用'),
  ],
  accountGroupIds: {'cash': 'fund', 'debt': 'credit'},
);

Finder _type(String text) => find.descendant(
  of: find.byType(AppSlidingSegmentedControl<AssetAccountFilter>),
  matching: find.text(text),
);

void _expectHeaderCentered(WidgetTester tester) {
  final header = tester.getRect(find.byType(AppPageHeader));
  final views = tester.getRect(find.byType(AppHeaderSelectButton<String>));
  final filter = tester.getRect(
    find.byType(AppSlidingSegmentedControl<AssetAccountFilter>),
  );
  final collapse = tester.getRect(find.byTooltip('折叠全部分组'));
  expect(filter.center.dx, moreOrLessEquals(header.center.dx));
  expect(filter.center.dy, moreOrLessEquals(views.center.dy));
  expect(filter.center.dy, moreOrLessEquals(collapse.center.dy));
  expect(filter.left, greaterThan(views.right));
  expect(filter.right, lessThan(collapse.left));
}

Future<void> _newView(
  WidgetTester tester,
  String name,
  List<String> accounts,
) async {
  await tester.tap(find.text('默认'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('新建'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.text('包含账户'));
  await tester.pumpAndSettle();
  for (final account in accounts) {
    await tester.tap(find.text(account));
  }
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness({List<AssetView> views = const [], String? selected}) {
    queries = FakeAssetViewQueryService(
      views: [
        AssetView(
          id: AssetView.defaultId,
          name: AssetView.defaultName,
          accountIds: accounts.map((account) => account.id),
          groups: [
            AssetViewGroup(id: 'fund', name: '资金'),
            AssetViewGroup(id: 'credit', name: '信用'),
          ],
          accountGroupIds: {
            'cash': 'fund',
            'outside': 'fund',
            'debt': 'credit',
          },
        ),
        ...views,
      ],
      profiles: {for (final account in accounts) account.id: account.kind},
      statistics: (view) {
        var assets = 0;
        var liabilities = 0;
        for (final account in accounts) {
          if (view.includesAccount(account.id)) {
            if (account.accountType == AccountType.asset) {
              assets += account.balance.minorUnits;
            } else {
              liabilities += account.balance.minorUnits;
            }
          }
        }
        return AssetViewStatistics(
          assets: Money(minorUnits: assets),
          liabilities: Money(minorUnits: liabilities),
          netAssetChange: const Money(minorUnits: 0),
        );
      },
    );
    commands = FakeAssetViewAppService(queries);
    preferences = MemoryAssetViewPreferences(selected);
    accountCommands = _ViewAccountCommands(this);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, state) => const AccountsPage()),
        GoRoute(
          path: '/assets/views/new',
          builder: (_, state) => AssetViewFormPage(
            copyFrom: state.extra is AssetView
                ? state.extra as AssetView
                : null,
          ),
        ),
        GoRoute(
          path: '/assets/views',
          builder: (_, state) => const AssetViewsPage(),
        ),
        GoRoute(
          path: '/assets/views/:id/edit',
          builder: (_, state) =>
              AssetViewFormPage(viewId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/account/new',
          builder: (_, state) => AccountFormPage(
            viewId: state.uri.queryParameters['view'],
            creationPreset: accountCreationPresetForId(
              state.uri.queryParameters['preset'],
            ),
          ),
        ),
        GoRoute(
          path: '/account/:id',
          builder: (_, state) => const Scaffold(body: Text('账户详情')),
        ),
      ],
    );
  }
  final accounts = <AccountView>[
    AccountView(
      id: 'cash',
      name: '账户A',
      kind: AccountProfileKind.fund,
      balance: Money(minorUnits: 10000),
      iconKey: null,
      isArchived: false,
    ),
    AccountView(
      id: 'outside',
      name: '范围外账户',
      kind: AccountProfileKind.fund,
      balance: Money(minorUnits: 20000),
      iconKey: null,
      isArchived: false,
    ),
    AccountView(
      id: 'debt',
      name: '信用账户B',
      kind: AccountProfileKind.credit,
      balance: Money(minorUnits: 5000),
      iconKey: null,
      isArchived: false,
    ),
  ];
  late final FakeAssetViewQueryService queries;
  late final FakeAssetViewAppService commands;
  late final _ViewAccountCommands accountCommands;
  late final MemoryAssetViewPreferences preferences;
  late final GoRouter router;
  Widget app({double textScale = 1}) => ProviderScope(
    overrides: [
      bookSelectionTestOverride,
      bookListTestOverride,
      assetViewQueryServiceProvider.overrideWithValue(queries),
      assetViewAppServiceProvider.overrideWithValue(commands),
      assetViewAccountAppServiceProvider.overrideWithValue(accountCommands),
      assetViewPreferencesStoreProvider.overrideWithValue(preferences),
      assetSectionCollapseStoreProvider.overrideWithValue(_Collapse()),
      accountViewsProvider.overrideWith((ref) => AsyncData(accounts)),
      archivedAccountViewsProvider.overrideWith((ref) => const AsyncData([])),
      accountListProvider.overrideWith(
        (ref) => queries.watchViews().map((_) => domainAccounts),
      ),
      accountQueryServiceProvider.overrideWithValue(
        FakeAssetAccountQueryService(domainAccounts),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  List<Account> get domainAccounts => [
    for (final account in accounts)
      Account(
        id: account.id,
        name: account.name,
        type: account.accountType,
        balance: account.balance,
        subtype: account.accountSubtype,
        profileKey: account.kind.key,
      ),
  ];
  void dispose() {
    router.dispose();
    unawaited(queries.close());
  }
}

class _Collapse implements AssetSectionCollapseStore {
  Set<String> values = {};
  @override
  Future<Set<String>> read() async => values;
  @override
  Future<void> save(Set<String> keys) async {
    values = {...keys};
  }
}

class _ViewAccountCommands implements AssetViewAccountAppService {
  _ViewAccountCommands(this.harness);
  final _Harness harness;
  final created = <CreateAssetViewAccountCommand>[];
  @override
  Future<String> createAccount(CreateAssetViewAccountCommand command) async {
    created.add(command);
    final id = 'new-account-${created.length}';
    harness.accounts.add(
      AccountView(
        id: id,
        name: command.account.name,
        kind: command.account.profile,
        balance: command.account.openingBalance,
        iconKey: command.account.iconKey,
        isArchived: false,
      ),
    );
    harness.queries.profiles[id] = command.account.profile;
    final index = harness.queries.views.indexWhere(
      (view) => view.id == command.viewId,
    );
    final view = harness.queries.views[index];
    harness.queries.views[index] = view.copyWith(
      accountIds: [...view.accountIds, id],
      accountGroupIds: {
        ...view.accountGroupIds,
        if (command.groupId != null) id: command.groupId!,
      },
      version: view.version + 1,
    );
    harness.queries.notify();
    return id;
  }

  @override
  Future<void> editAccount(EditAssetViewAccountCommand command) async {}
}
