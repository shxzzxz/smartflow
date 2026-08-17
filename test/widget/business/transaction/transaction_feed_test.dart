import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

void main() {
  testWidgets('renders long transaction text on a common Android phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: TransactionFeedScrollView(
            groups: [_group(0, title: '周末家庭聚餐与日常生活用品采购')],
          ),
        ),
      ),
    );

    expect(find.text('周末家庭聚餐与日常生活用品采购'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders date-grouped transactions through the shared feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionFeedScrollView(
            groups: [_group(0)],
            showDailyTotals: false,
            isLoadingMore: true,
          ),
        ),
      ),
    );

    expect(find.text('7月14日'), findsOneWidget);
    expect(find.text('测试交易 0'), findsOneWidget);
    expect(find.text('收入 100.00'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('requests one next page near the end and suppresses duplicates', (
    tester,
  ) async {
    var loadMoreCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: TransactionFeedScrollView(
              groups: [for (var i = 0; i < 12; i++) _group(i)],
              hasMore: true,
              onLoadMore: () => loadMoreCount += 1,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    expect(loadMoreCount, 1);
  });

  testWidgets('shows a retry footer without automatically retrying', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionFeedScrollView(
            groups: [for (var i = 0; i < 8; i++) _group(i)],
            hasMore: true,
            loadMoreErrorMessage: '加载更多交易失败，请重试',
            onLoadMore: () => retryCount += 1,
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('加载更多交易失败，请重试'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(retryCount, 0);
    expect(find.text('加载更多交易失败，请重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(retryCount, 1);
  });

  testWidgets('keeps quick edit navigation available inside the shared feed', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => Scaffold(
                body: TransactionFeedScrollView(
                  groups: [_group(0, canQuickEdit: true)],
                ),
              ),
        ),
        GoRoute(
          path: '/transaction/:id/edit',
          builder: (context, state) => const Scaffold(body: Text('编辑交易')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );

    expect(find.byType(AppSwipeAction), findsOneWidget);
    await tester.drag(find.byType(TransactionRow), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('编辑交易'), findsOneWidget);
  });

  testWidgets(
    'forwards long press and selection callbacks to transaction rows',
    (tester) async {
      String? longPressedId;
      String? changedId;
      bool? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransactionFeedScrollView(
              groups: [
                _group(0).copyWith(
                  rows: [_group(0).rows.single.copyWith(selectable: true)],
                ),
              ],
              onRowLongPress: (id) => longPressedId = id,
              onRowSelectionChanged: (id, selected) {
                changedId = id;
                changedValue = selected;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(TransactionRow));
      await tester.tap(find.byType(Checkbox));

      expect(longPressedId, 'tx-0');
      expect(changedId, 'tx-0');
      expect(changedValue, isTrue);
    },
  );
}

TransactionDayGroup _group(
  int index, {
  bool canQuickEdit = false,
  String? title,
}) {
  return TransactionDayGroup(
    date: DateTime(2026, 7, 14 - index),
    rows: [
      TransactionRowPresentation(
        transactionId: 'tx-$index',
        iconKey: null,
        title: title ?? '测试交易 $index',
        subtitle: '08:00',
        amountText: '-10.00',
        amountTone: FinanceTone.expense,
        accountFlow: const TransactionAccountFlowPresentation(
          fallbackLabel: '现金',
        ),
        badges: const [],
        canQuickEdit: canQuickEdit,
      ),
    ],
    incomeMinor: 10000,
    expenseMinor: 1000,
  );
}
