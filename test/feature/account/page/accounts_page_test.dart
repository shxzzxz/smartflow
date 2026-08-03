// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/asset_section_collapse_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/account/page/accounts_page.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
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

    await tester.tap(find.byTooltip('隐藏余额'));
    await tester.pump();

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
  );
}

Widget _buildAccountsPageApp({
  List<AccountView> accounts = const [],
  AssetSectionCollapseStore? collapseStore,
}) {
  return ProviderScope(
    overrides: [
      accountViewsProvider.overrideWith((ref) => AsyncValue.data(accounts)),
      archivedAccountViewsProvider.overrideWith(
        (ref) => const AsyncValue.data([]),
      ),
      accountGroupsProvider.overrideWith(
        (ref) => Stream.value([
          AccountGroup(id: 'fund', name: '资金'),
          AccountGroup(id: 'credit', name: '信用'),
          AccountGroup(id: 'loan', name: '贷款'),
          AccountGroup(id: 'reimbursement', name: '报销'),
        ]),
      ),
      assetSectionCollapseStoreProvider.overrideWith(
        (ref) => collapseStore ?? _InMemoryAssetSectionCollapseStore(),
      ),
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
