import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/feature/transaction/page/filtered_transactions_page.dart';
import 'package:smartflow/feature/transaction/view_model/filtered_transactions_view_model.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  testWidgets('renders filtered feed and opens transaction detail', (
    tester,
  ) async {
    final state = FilteredTransactionsState.loaded(
      title: '旅行',
      subtitle: '标签交易',
      emptyMessage: '该标签暂无交易',
      groups: [
        TransactionDayGroup(
          date: _transactionDate,
          incomeMinor: 0,
          expenseMinor: 1234,
          rows: const [
            TransactionRowPresentation(
              transactionId: 'tx-1',
              iconKey: 'meal',
              title: '餐饮',
              subtitle: '12:30',
              amountText: '-12.34',
              amountTone: FinanceTone.expense,
              accountFlow: TransactionAccountFlowPresentation(
                fallbackLabel: '现金',
              ),
              badges: [],
              canQuickEdit: false,
            ),
          ],
        ),
      ],
      hasMore: false,
      isLoadingMore: false,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, routeState) => const FilteredTransactionsPage(
            target: FilteredTransactionTarget.tag,
            targetId: 'travel',
          ),
        ),
        GoRoute(
          path: '/transaction/:id',
          builder: (context, routeState) =>
              Scaffold(body: Text('交易详情:${routeState.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredTransactionsViewModelProvider(
            FilteredTransactionTarget.tag,
            'travel',
          ).overrideWithValue(state),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('标签交易'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('-12.34'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('交易详情:tx-1'), findsOneWidget);
  });
}

final _transactionDate = DateTime(2026, 8, 26);
