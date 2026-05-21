import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/database_provider.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/features/home/widgets/transaction_row.dart' as home;
import 'package:smartflow/widgets/business/business_icon.dart';

import '../../helpers/test_app_database.dart';

void main() {
  testWidgets('renders icons for both flow accounts', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final outAccountId = await _insertAccount(
      database,
      name: '支付宝',
      iconKey: 'alipay',
    );
    final inAccountId = await _insertAccount(
      database,
      name: '微信',
      iconKey: 'wechat_pay',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: home.TransactionRow(
              item: TransactionListItem(
                id: 1,
                businessPurpose: BusinessPurpose.transfer,
                occurredAt: DateTime(2026, 5, 12, 8, 30),
                primaryAmount: const Money(minorUnits: 1000),
                accountNames: '支付宝 / 微信',
                flowOutAccountId: outAccountId,
                flowInAccountId: inAccountId,
                flowOutAccountName: '支付宝',
                flowInAccountName: '微信',
                isExcludedFromStats: false,
                isExcludedFromBudget: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('支付宝'), findsOneWidget);
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('|'), findsNothing);
    final iconKeys = tester
        .widgetList<BusinessIcon>(find.byType(BusinessIcon))
        .map((widget) => widget.iconKey);
    expect(iconKeys, containsAll(['transfer', 'alipay', 'wechat_pay']));
  });

  testWidgets('renders reimbursement account before out account for advance', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final outAccountId = await _insertAccount(
      database,
      name: '信用卡',
      iconKey: 'cmb_credit_card',
    );
    final inAccountId = await _insertAccount(
      database,
      name: '公司报销',
      iconKey: 'reimburse',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: home.TransactionRow(
              item: TransactionListItem(
                id: 2,
                businessPurpose: BusinessPurpose.reimbursementAdvance,
                occurredAt: DateTime(2026, 5, 12, 8, 30),
                primaryAmount: const Money(minorUnits: 1000),
                accountNames: '信用卡 / 公司报销',
                categoryName: '电费',
                flowOutAccountId: outAccountId,
                flowInAccountId: inAccountId,
                flowOutAccountName: '信用卡',
                flowInAccountName: '公司报销',
                isExcludedFromStats: false,
                isExcludedFromBudget: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('公司报销'), findsOneWidget);
    expect(find.text('信用卡'), findsOneWidget);
    expect(find.text('|'), findsOneWidget);
    expect(find.text('→'), findsNothing);
    expect(
      tester.getTopLeft(find.text('公司报销')).dx,
      lessThan(tester.getTopLeft(find.text('信用卡')).dx),
    );
    final iconKeys = tester
        .widgetList<BusinessIcon>(find.byType(BusinessIcon))
        .map((widget) => widget.iconKey);
    expect(iconKeys, contains('cmb_credit_card'));
    expect(iconKeys, contains('reimburse'));
  });

  testWidgets('tap transfer row opens transaction detail route', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => Scaffold(
                body: home.TransactionRow(
                  item: TransactionListItem(
                    id: 3,
                    businessPurpose: BusinessPurpose.transfer,
                    occurredAt: DateTime(2026, 5, 12, 8, 30),
                    primaryAmount: const Money(minorUnits: 1000),
                    accountNames: '支付宝 / 微信',
                    isExcludedFromStats: false,
                    isExcludedFromBudget: false,
                  ),
                ),
              ),
        ),
        GoRoute(
          path: '/transactions/:id',
          builder:
              (context, state) => Text("detail ${state.pathParameters['id']}"),
        ),
        GoRoute(
          path: '/transactions/:id/edit',
          builder:
              (context, state) => Text("edit ${state.pathParameters['id']}"),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(home.TransactionRow));
    await tester.pumpAndSettle();

    expect(find.text('detail 3'), findsOneWidget);
    expect(find.text('edit 3'), findsNothing);
  });

  testWidgets('right swipe transfer row opens transaction edit route', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final router = _buildTransactionRowRouter(
      item: TransactionListItem(
        id: 4,
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: DateTime(2026, 5, 12, 8, 30),
        primaryAmount: const Money(minorUnits: 1000),
        accountNames: '支付宝 / 微信',
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(home.TransactionRow), const Offset(360, 0));
    await tester.pumpAndSettle();

    expect(find.text('edit 4'), findsOneWidget);
    expect(find.text('detail 4'), findsNothing);
  });

  testWidgets('right swipe returned below threshold cancels quick edit', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final router = _buildTransactionRowRouter(
      item: TransactionListItem(
        id: 5,
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: DateTime(2026, 5, 12, 8, 30),
        primaryAmount: const Money(minorUnits: 1000),
        accountNames: '支付宝 / 微信',
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(home.TransactionRow)),
    );
    await gesture.moveBy(const Offset(360, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(home.TransactionRow), findsOneWidget);
    expect(find.text('edit 5'), findsNothing);
    expect(find.text('detail 5'), findsNothing);
  });
}

GoRouter _buildTransactionRowRouter({required TransactionListItem item}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) => Scaffold(body: home.TransactionRow(item: item)),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder:
            (context, state) => Text("detail ${state.pathParameters['id']}"),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (context, state) => Text("edit ${state.pathParameters['id']}"),
      ),
    ],
  );
}

Future<int> _insertAccount(
  AppDatabase database, {
  required String name,
  required String iconKey,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          accountType: AccountType.asset,
          currencyCode: 'CNY',
          iconKey: Value(iconKey),
        ),
      );
}
