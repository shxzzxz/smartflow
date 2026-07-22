// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/account/page/accounts_page.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

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
}

Widget _buildAccountsPageApp() {
  return ProviderScope(
    overrides: [
      accountViewsProvider.overrideWith((ref) => const AsyncValue.data([])),
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
