import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/budget/page/budget_page.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  testWidgets('shows total usage trend and grouped parent-child budgets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final visibleMonth = DateTime(2026, 8);
    final total = _progress(
      id: 'total',
      name: '总预算',
      budget: 200000,
      spent: 60000,
      trend: [
        BudgetTrendPoint(
          date: DateTime(2026, 8, 5),
          spent: const Money(minorUnits: 60000),
          remaining: const Money(minorUnits: 140000),
        ),
      ],
    );
    final food = _progress(
      id: 'food-budget',
      categoryId: 'food',
      name: '餐饮',
      budget: 100000,
      spent: 30000,
    );
    final lunch = _progress(
      id: 'lunch-budget',
      categoryId: 'lunch',
      name: '午餐',
      budget: 50000,
      spent: 20000,
      sortOrder: 1,
    );
    final report = MonthlyBudgetReport(
      month: MonthKey(year: 2026, month: 8),
      totalBudget: total,
      categoryGroups: [
        BudgetCategoryGroup(
          id: 'food',
          name: '餐饮',
          sortOrder: 0,
          rootBudget: food,
          childBudgets: [lunch],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateTimeProvider.overrideWith((ref) => visibleMonth),
          monthlyBudgetReportProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(report)),
          categoryTreeProvider(
            AccountType.expense,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BudgetPage(initialMonth: null),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('预算'), findsWidgets);
    expect(find.text('预算趋势'), findsOneWidget);
    expect(find.text('剩余预算'), findsOneWidget);
    expect(find.text('预算支出'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('剩余 700.00'), findsOneWidget);
    expect(find.text('剩余 300.00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('编辑总预算'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '2000.00',
    );
    expect(tester.takeException(), isNull);
  });
}

BudgetProgress _progress({
  required String id,
  required String name,
  required int budget,
  required int spent,
  String? categoryId,
  int sortOrder = 0,
  List<BudgetTrendPoint> trend = const [],
}) {
  return BudgetProgress(
    id: id,
    categoryId: categoryId,
    name: name,
    budget: Money(minorUnits: budget),
    spent: Money(minorUnits: spent),
    sortOrder: sortOrder,
    trend: trend,
  );
}
