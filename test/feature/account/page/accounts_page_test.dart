// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/account/command/account_group_app_service.dart';
import 'package:smartflow/application/ledger/account/command/account_group_command.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/asset_section_collapse_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/feature/account/page/accounts_page.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';

void main() {
  testWidgets('shows a signed neutral net amount for each account group', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildAccountsPageApp(accounts: [_fundAccount(), _creditAccount()]),
    );
    await tester.pumpAndSettle();

    final positiveNet = tester.widget<Text>(find.text('+100.00'));
    final negativeNet = tester.widget<Text>(find.text('-50.00'));
    final neutralColor = AppTheme.light().colorScheme.onSurface;

    expect(positiveNet.style?.color, neutralColor);
    expect(negativeNet.style?.color, neutralColor);
  });

  testWidgets('keeps account rows aligned when supporting text is present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildAccountsPageApp(accounts: [_fundAccount(), _creditAccount()]),
    );
    await tester.pumpAndSettle();

    final fundRow =
        find
            .ancestor(of: find.text('招行储蓄卡'), matching: find.byType(InkWell))
            .first;
    final creditRow =
        find
            .ancestor(of: find.text('招行信用卡'), matching: find.byType(InkWell))
            .first;
    final supportingText = find.text('出账日 1   还款日 15');
    final creditAmount = find.descendant(
      of: creditRow,
      matching: find.text('50.00'),
    );
    final creditIcon = find.descendant(
      of: creditRow,
      matching: find.byType(BusinessIconBubble),
    );

    expect(
      tester.getSize(creditRow).height,
      closeTo(tester.getSize(fundRow).height, 0.1),
    );
    expect(
      tester.getCenter(creditAmount).dy,
      closeTo(tester.getCenter(creditRow).dy, 1),
    );
    expect(
      tester.getCenter(creditIcon).dy,
      closeTo(tester.getCenter(creditRow).dy, 1),
    );
    expect(
      tester.getTopLeft(supportingText).dx,
      closeTo(tester.getTopLeft(find.text('招行信用卡')).dx, 1),
    );
    expect(find.textContaining('|'), findsNothing);
  });

  testWidgets('keeps a long account amount on one line', (tester) async {
    await tester.pumpWidget(
      _buildAccountsPageApp(accounts: [_largeFundAccount()]),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.text('9000000000000000.00')).height,
      lessThan(AppSpacing.space24),
    );
  });

  testWidgets('places a group header and its accounts on one surface', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAccountsPageApp(accounts: [_fundAccount()]));
    await tester.pumpAndSettle();

    final groupSurface =
        find
            .ancestor(of: find.text('资金'), matching: find.byType(AppSurface))
            .first;

    expect(
      find.descendant(of: groupSurface, matching: find.text('招行储蓄卡')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: groupSurface, matching: find.byType(AppSurface)),
      findsNothing,
    );
  });

  testWidgets('shows archived accounts as a compact entry', (tester) async {
    await tester.pumpWidget(
      _buildAccountsPageApp(
        archivedAccounts: [_archivedCreditAccount()],
        groups: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已归档账户'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('已归档招行信用卡'), findsNothing);
    expect(find.byIcon(RemixIcons.archive_line), findsNothing);
  });

  testWidgets('shows asset and liability amounts in the donut legend', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAccountsPageApp());
    await tester.pumpAndSettle();

    final assetLegend = find.byKey(const ValueKey('asset-balance-legend'));
    final liabilityLegend = find.byKey(
      const ValueKey('liability-balance-legend'),
    );

    expect(find.text('资产占比'), findsNothing);
    expect(find.text('负债占比'), findsNothing);
    expect(
      find.descendant(of: assetLegend, matching: find.text('资产')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: liabilityLegend, matching: find.text('负债')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: assetLegend, matching: find.text('-17.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: liabilityLegend, matching: find.text('327.72')),
      findsOneWidget,
    );
  });

  testWidgets('hides asset and liability legend amounts', (tester) async {
    await tester.pumpWidget(_buildAccountsPageApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏余额'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('asset-balance-legend')),
        matching: find.text('¥ ****'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('liability-balance-legend')),
        matching: find.text('¥ ****'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows empty predefined groups without accounts', (tester) async {
    await tester.pumpWidget(_buildAccountsPageApp());
    await tester.pumpAndSettle();

    expect(find.text('还没有账户，点击右上角"+"新建'), findsNothing);
    expect(find.text('资金'), findsOneWidget);
    expect(find.text('信用'), findsOneWidget);
    expect(find.byTooltip('折叠全部分组'), findsOneWidget);
  });

  testWidgets('renders only sections that have accounts', (tester) async {
    await tester.pumpWidget(_buildAccountsPageApp(accounts: [_fundAccount()]));
    await tester.pumpAndSettle();

    expect(find.text('资金'), findsOneWidget);
    expect(find.text('招行储蓄卡'), findsOneWidget);
    expect(find.text('信用'), findsOneWidget);
  });

  testWidgets('collapses and expands a section on header tap', (tester) async {
    final store = _InMemoryAssetSectionCollapseStore();
    await tester.pumpWidget(
      _buildAccountsPageApp(accounts: [_fundAccount()], collapseStore: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('资金'));
    await tester.pumpAndSettle();

    expect(find.text('招行储蓄卡'), findsNothing);
    expect(find.text('资金'), findsOneWidget);
    expect(store.collapsed, {'fund'});

    await tester.tap(find.text('资金'));
    await tester.pumpAndSettle();

    expect(find.text('招行储蓄卡'), findsOneWidget);
    expect(store.collapsed, isEmpty);
  });

  testWidgets('collapse-all button toggles every section', (tester) async {
    final store = _InMemoryAssetSectionCollapseStore();
    await tester.pumpWidget(
      _buildAccountsPageApp(
        accounts: [_fundAccount(), _creditAccount()],
        collapseStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('折叠全部分组'));
    await tester.pumpAndSettle();

    expect(find.text('招行储蓄卡'), findsNothing);
    expect(find.text('招行信用卡'), findsNothing);
    expect(store.collapsed, {'fund', 'credit', 'loan', 'reimbursement'});

    await tester.tap(find.byTooltip('展开全部分组'));
    await tester.pumpAndSettle();

    expect(find.text('招行储蓄卡'), findsOneWidget);
    expect(find.text('招行信用卡'), findsOneWidget);
    expect(store.collapsed, isEmpty);
  });

  testWidgets('restores persisted collapse state', (tester) async {
    final store = _InMemoryAssetSectionCollapseStore()..collapsed = {'fund'};
    await tester.pumpWidget(
      _buildAccountsPageApp(accounts: [_fundAccount()], collapseStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('资金'), findsOneWidget);
    expect(find.text('招行储蓄卡'), findsNothing);
  });

  testWidgets('keeps collapse, add, and more actions in that order', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAccountsPageApp());
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.byTooltip('折叠全部分组')).dx,
      lessThan(tester.getCenter(find.byTooltip('新建账户')).dx),
    );
    expect(
      tester.getCenter(find.byTooltip('新建账户')).dx,
      lessThan(tester.getCenter(find.byTooltip('更多操作')).dx),
    );

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('管理分组'), findsOneWidget);
    expect(find.text('隐藏余额'), findsOneWidget);
  });

  testWidgets('starts group sorting after a delayed long press', (
    tester,
  ) async {
    final groupService = _FakeAccountGroupAppService();
    await tester.pumpWidget(_buildAccountsPageApp(groupService: groupService));
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.text('贷款'));
    final to = tester.getCenter(find.text('资金'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(groupService.reorderedGroupIds, [
      'loan',
      'fund',
      'credit',
      'reimbursement',
    ]);
  });

  testWidgets('starts account sorting after a delayed long press', (
    tester,
  ) async {
    final groupService = _FakeAccountGroupAppService();
    await tester.pumpWidget(
      _buildAccountsPageApp(
        accounts: [_fundAccount(), _secondFundAccount()],
        groupService: groupService,
      ),
    );
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.text('招行储蓄卡'));
    final to = tester.getCenter(find.text('另一张储蓄卡'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to + const Offset(0, 72));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(groupService.movedCommands.single.orderedAccountIds, [
      'fund-2',
      'fund-1',
    ]);
  });
}

class _InMemoryAssetSectionCollapseStore implements AssetSectionCollapseStore {
  Set<String> collapsed = {};

  @override
  Future<Set<String>> read() async => collapsed;

  @override
  Future<void> save(Set<String> collapsedSectionKeys) async {
    collapsed = collapsedSectionKeys;
  }
}

AccountView _fundAccount() {
  return const AccountView(
    id: 'fund-1',
    name: '招行储蓄卡',
    kind: AccountProfileKind.fund,
    balance: Money(minorUnits: 10000),
    iconKey: null,
    isArchived: false,
    groupId: 'fund',
  );
}

AccountView _creditAccount() {
  return const AccountView(
    id: 'credit-1',
    name: '招行信用卡',
    kind: AccountProfileKind.credit,
    balance: Money(minorUnits: 5000),
    iconKey: null,
    isArchived: false,
    groupId: 'credit',
    billingDay: 1,
    repaymentDay: 15,
  );
}

AccountView _secondFundAccount() {
  return const AccountView(
    id: 'fund-2',
    name: '另一张储蓄卡',
    kind: AccountProfileKind.fund,
    balance: Money(minorUnits: 20000),
    iconKey: null,
    isArchived: false,
    groupId: 'fund',
  );
}

AccountView _largeFundAccount() {
  return const AccountView(
    id: 'fund-large',
    name: '大额资金账户',
    kind: AccountProfileKind.fund,
    balance: Money(minorUnits: 900000000000000000),
    iconKey: null,
    isArchived: false,
    groupId: 'fund',
  );
}

AccountView _archivedCreditAccount() {
  return const AccountView(
    id: 'archived-credit-1',
    name: '已归档招行信用卡',
    kind: AccountProfileKind.credit,
    balance: Money(minorUnits: 5000),
    iconKey: null,
    isArchived: true,
    groupId: 'credit',
    billingDay: 1,
    repaymentDay: 15,
  );
}

Widget _buildAccountsPageApp({
  List<AccountView> accounts = const [],
  List<AccountView> archivedAccounts = const [],
  List<AccountGroup>? groups,
  AssetSectionCollapseStore? collapseStore,
  AccountGroupAppService? groupService,
}) {
  return ProviderScope(
    overrides: [
      accountViewsProvider.overrideWith((ref) => AsyncValue.data(accounts)),
      archivedAccountViewsProvider.overrideWith(
        (ref) => AsyncValue.data(archivedAccounts),
      ),
      accountGroupsProvider.overrideWith(
        (ref) => Stream.value(
          groups ??
              [
                AccountGroup(id: 'fund', name: '资金'),
                AccountGroup(id: 'credit', name: '信用'),
                AccountGroup(id: 'loan', name: '贷款'),
                AccountGroup(id: 'reimbursement', name: '报销'),
              ],
        ),
      ),
      assetSectionCollapseStoreProvider.overrideWith(
        (ref) => collapseStore ?? _InMemoryAssetSectionCollapseStore(),
      ),
      if (groupService != null)
        accountGroupAppServiceProvider.overrideWithValue(groupService),
      balanceSheetComparisonProvider.overrideWith(
        (ref) => Stream.value(
          const BalanceSheetComparison(
            current: BalanceSheetSnapshot(
              assets: Money(minorUnits: -1700),
              liabilities: Money(minorUnits: 32772),
            ),
            previous: BalanceSheetSnapshot(
              assets: Money(minorUnits: -2000),
              liabilities: Money(minorUnits: 30000),
            ),
          ),
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const AccountsPage()),
  );
}

class _FakeAccountGroupAppService implements AccountGroupAppService {
  List<String>? reorderedGroupIds;
  final movedCommands = <MoveAccountToGroupCommand>[];

  @override
  Future<void> reorderGroups(ReorderAccountGroupsCommand command) async {
    reorderedGroupIds = command.orderedIds;
  }

  @override
  Future<void> moveAccountToGroup(MoveAccountToGroupCommand command) async {
    movedCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
