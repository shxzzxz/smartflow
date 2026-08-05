// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/ledger/entity/account_group.dart';
import 'package:smartflow/feature/account/page/archived_accounts_page.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  testWidgets('shows archived accounts with their normal supporting details', (
    tester,
  ) async {
    await tester.pumpWidget(_buildArchivedAccountsPage());
    await tester.pumpAndSettle();

    expect(find.text('信用'), findsOneWidget);
    expect(find.text('1 个账户'), findsOneWidget);
    expect(find.text('已归档招行信用卡'), findsOneWidget);
    expect(find.text('出账日 1   还款日 15'), findsOneWidget);
    expect(find.text('不计入资产与负债统计'), findsNothing);
    expect(find.text('不计入资产和负债统计'), findsNothing);
    expect(find.widgetWithText(TextButton, '恢复'), findsNothing);

    final amount = tester.widget<Text>(find.text('50.00'));
    expect(amount.style?.color, AppTheme.light().colorScheme.onSurface);
  });

  testWidgets('opens archived account details from its row', (tester) async {
    final router = GoRouter(
      initialLocation: '/archived-accounts',
      routes: [
        GoRoute(
          path: '/archived-accounts',
          builder: (context, state) => const ArchivedAccountsPage(),
        ),
        GoRoute(
          path: '/account/:id',
          builder:
              (context, state) =>
                  Scaffold(body: Text('账户详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_buildArchivedAccountsPage(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已归档招行信用卡'));
    await tester.pumpAndSettle();

    expect(find.text('账户详情 archived-credit-1'), findsOneWidget);
  });

  testWidgets('does not expose technical details when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildArchivedAccountsPage(
        archivedAccounts: AsyncValue<List<AccountView>>.error(
          StateError('database connection details'),
          StackTrace.empty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已归档账户加载失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('database connection details'), findsNothing);
  });

  testWidgets('collapses and expands an archived account group', (
    tester,
  ) async {
    await tester.pumpWidget(_buildArchivedAccountsPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('信用'));
    await tester.pumpAndSettle();

    expect(find.text('信用'), findsOneWidget);
    expect(find.text('已归档招行信用卡'), findsNothing);

    await tester.tap(find.text('信用'));
    await tester.pumpAndSettle();

    expect(find.text('已归档招行信用卡'), findsOneWidget);
  });
}

Widget _buildArchivedAccountsPage({
  AsyncValue<List<AccountView>>? archivedAccounts,
  GoRouter? router,
}) {
  final archivedAccountValue =
      archivedAccounts ??
      const AsyncValue.data([
        AccountView(
          id: 'archived-credit-1',
          name: '已归档招行信用卡',
          kind: AccountProfileKind.credit,
          balance: Money(minorUnits: 5000),
          iconKey: null,
          isArchived: true,
          groupId: 'credit',
          billingDay: 1,
          repaymentDay: 15,
        ),
      ]);
  return ProviderScope(
    overrides: [
      archivedAccountViewsProvider.overrideWith((ref) => archivedAccountValue),
      accountGroupsProvider.overrideWith(
        (ref) => Stream.value([
          AccountGroup(id: 'fund', name: '资金'),
          AccountGroup(id: 'credit', name: '信用'),
        ]),
      ),
    ],
    child:
        router == null
            ? MaterialApp(
              theme: AppTheme.light(),
              home: const ArchivedAccountsPage(),
            )
            : MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}
