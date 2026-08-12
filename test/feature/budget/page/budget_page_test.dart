import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/budget/page/budget_page.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  testWidgets('shows budget trend and grouped parent-child budgets', (
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
    final dinner = _progress(
      id: 'dinner-budget',
      categoryId: 'dinner',
      name: '晚餐',
      budget: 30000,
      spent: 10000,
      sortOrder: 2,
    );
    final budgetService = _RecordingBudgetAppService();
    final report = MonthlyBudgetReport(
      month: MonthKey(year: 2026, month: 8),
      totalBudget: total,
      categoryGroups: [
        BudgetCategoryGroup(
          id: 'food',
          name: '餐饮',
          sortOrder: 0,
          rootBudget: food,
          childBudgets: [lunch, dinner],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetAppServiceProvider.overrideWithValue(budgetService),
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
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

    expect(find.text('2026年8月预算'), findsOneWidget);
    expect(find.text('预算趋势'), findsOneWidget);
    expect(find.byTooltip('横屏查看预算趋势'), findsNothing);
    expect(find.text('余'), findsOneWidget);
    expect(find.text('支'), findsOneWidget);
    expect(find.text('餐饮'), findsNWidgets(2));
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);
    expect(find.text('余700.00'), findsOneWidget);
    expect(find.text('余300.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('编辑总预算'), findsNothing);
    expect(find.text('月度支出目标'), findsNothing);
    expect(find.text('分类预算'), findsNothing);
    expect(find.byIcon(RemixIcons.draggable), findsNothing);
    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(3));
    final rootBudgetName = find.text('餐饮').at(1);
    final groupHeaderName = find.text('餐饮').at(0);
    expect(
      tester.getTopLeft(groupHeaderName).dx,
      tester.getTopLeft(rootBudgetName).dx,
    );
    expect(
      tester.getTopLeft(rootBudgetName).dx,
      tester.getTopLeft(find.text('午餐')).dx,
    );
    expect(
      tester.getTopLeft(rootBudgetName).dy,
      lessThan(tester.getTopLeft(find.text('午餐')).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('收起分组'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);
    expect(find.text('晚餐'), findsNothing);
    expect(find.byTooltip('展开分组'), findsOneWidget);

    await tester.tap(find.byTooltip('展开分组'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsNWidgets(2));
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);

    await tester.ensureVisible(find.text('午餐'));
    final lunchCenter = tester.getCenter(find.text('午餐'));
    final dinnerCenter = tester.getCenter(find.text('晚餐'));
    final reorderGesture = await tester.startGesture(lunchCenter);
    await tester.pump(const Duration(milliseconds: 600));
    await reorderGesture.moveTo(dinnerCenter + const Offset(0, 72));
    await tester.pump();
    await reorderGesture.up();
    await tester.pumpAndSettle();

    expect(budgetService.reorderCommands, hasLength(1));
    expect(budgetService.reorderCommands.single.orderedBudgetIds, [
      food.id,
      dinner.id,
      lunch.id,
    ]);
    expect(
      tester.getTopLeft(find.text('晚餐')).dy,
      lessThan(tester.getTopLeft(find.text('午餐')).dy),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('设置总预算'), findsOneWidget);
    expect(find.text('清空本月预算'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('设置总预算')).dy,
      lessThan(tester.getTopLeft(find.text('清空本月预算')).dy),
    );
    expect(
      tester.getTopLeft(find.text('清空本月预算')).dy,
      lessThan(tester.getTopLeft(find.text('复制上月预算')).dy),
    );

    await tester.tap(find.text('复制上月预算'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('复制上月预算'), findsOneWidget);
    expect(find.text('已开启复制上月预算'), findsOneWidget);
    expect(budgetService.copyCommands, isEmpty);

    await tester.tap(find.text('清空本月预算'));
    await tester.pumpAndSettle();
    expect(find.text('清空本月预算？'), findsOneWidget);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(budgetService.clearCommands, hasLength(1));
    expect(budgetService.clearCommands.single.month, report.month);
  });
}

class _RecordingBudgetAppService implements BudgetAppService {
  final reorderCommands = <ReorderCategoryBudgetsCommand>[];
  final clearCommands = <ClearMonthBudgetsCommand>[];
  final copyCommands = <CopyPreviousMonthBudgetsCommand>[];

  @override
  Future<void> clearMonthBudgets(ClearMonthBudgetsCommand command) {
    clearCommands.add(command);
    return Future.value();
  }

  @override
  Future<bool> copyPreviousMonthBudgets(
    CopyPreviousMonthBudgetsCommand command,
  ) {
    copyCommands.add(command);
    return Future.value(true);
  }

  @override
  Future<void> reorderCategoryBudgets(ReorderCategoryBudgetsCommand command) {
    reorderCommands.add(command);
    return Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemorySettingsStore implements AppSettingsStore {
  AppSettings settings = const AppSettings();

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
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
