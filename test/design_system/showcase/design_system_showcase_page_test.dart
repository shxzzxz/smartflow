import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/showcase/design_system_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_empty_state.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_grouped_choice_grid.dart';
import 'package:smartflow/design_system/widget/app_inline_action_button.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';
import 'package:smartflow/design_system/widget/app_list_section.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_status_banner.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/design_system/widget/app_submit_button.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/finance/cashflow_summary_card.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';
import 'package:smartflow/widget/business/icon/icon_choice_grid.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import 'package:smartflow/widget/business/transaction/transaction_progress_badges.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

const _showcaseCategoryLabels = [
  '设计基础',
  '基础控件',
  '表单与输入',
  '选择器与弹层',
  '反馈与状态',
  '布局与容器',
  '数据展示',
  '财务表达',
  '业务图标',
  '交易与列表',
];

// Component suites cover states and layout; this suite covers showcase
// navigation, search, preview registration, and example callbacks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessIconRegistry iconCatalog;
  setUpAll(() async {
    iconCatalog = await BusinessIconRegistry.load(rootBundle);
  });

  Future<void> pumpShowcase(
    WidgetTester tester, {
    Size surfaceSize = const Size(360, 800),
    TextScaler textScaler = TextScaler.noScaling,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: BusinessIconScope(
          registry: iconCatalog,
          child: const DesignSystemShowcasePage(),
        ),
      ),
    );
  }

  testWidgets('supports dark mode and large text across component categories', (
    tester,
  ) async {
    await pumpShowcase(
      tester,
      surfaceSize: const Size(360, 800),
      textScaler: const TextScaler.linear(2),
      themeMode: ThemeMode.dark,
    );

    final tabBar = find.byType(TabBar);
    final categoryController = tester.widget<TabBar>(tabBar).controller!;
    for (final category in _showcaseCategoryLabels) {
      final categoryTab = find.text(category);
      for (var attempt = 0; attempt < 10; attempt++) {
        if (categoryTab.hitTestable().evaluate().isNotEmpty) break;
        await tester.drag(tabBar, const Offset(-80, 0));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(categoryTab.hitTestable(), findsOneWidget, reason: category);
      await tester.tap(categoryTab.hitTestable());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        categoryController.index,
        _showcaseCategoryLabels.indexOf(category),
        reason: category,
      );
      if (category == '基础控件') {
        expect(
          find.text('FilledButton / OutlinedButton / TextButton'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull, reason: category);
    }

    expect(
      Theme.of(
        tester.element(find.byType(DesignSystemShowcasePage)),
      ).brightness,
      Brightness.dark,
    );
  });

  testWidgets('shows mobile categories and switches the visible examples', (
    tester,
  ) async {
    await pumpShowcase(tester);

    expect(find.text('组件示例'), findsOneWidget);
    expect(find.text('搜索组件'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    for (final category in _showcaseCategoryLabels) {
      expect(find.text(category), findsOneWidget);
    }

    final financeCategory = find.text('财务表达');
    await tester.ensureVisible(financeCategory);
    await tester.tap(financeCategory);
    await tester.pumpAndSettle();

    expect(find.text('金额文本'), findsOneWidget);
    expect(find.text('色彩语义'), findsNothing);
  });

  testWidgets('finds component families and replaces the previous search', (
    tester,
  ) async {
    await pumpShowcase(tester);

    const examples = <String, (String, Type?, Type?)>{
      'AppDetailSummaryCard': ('详情概览卡片', null, null),
      'FinanceActivityRow': ('动态记录', null, null),
      'InsuranceCoverageOverviewCard': ('保障责任卡片', null, null),
      'AppTextFormField': ('表单字段', null, null),
      'AppPlainFormRow': ('基础表单行', null, null),
      'AppSelectMenu': ('选择菜单', null, null),
      'CategoryProgressListItem': ('分类进度项', null, null),
      'TreeSelect': ('树形选择', null, null),
      'TransactionFeedScrollView': ('交易 Feed', null, null),
      'AppSpacing': ('间距', null, null),
      'AppRadius': ('圆角', null, null),
      'TransactionRow': ('交易行', TransactionRow, EmptyTransactionCard),
      'EmptyTransactionCard': ('空状态', EmptyTransactionCard, TransactionRow),
      'AppEmptyState': ('空状态面板', AppEmptyState, null),
      'AppPlainTextFormRow': ('文本输入行', AppPlainTextFormRow, AppSubmitButton),
      'MoneyPlainFormRow': ('金额输入行', MoneyPlainFormRow, null),
      'TransactionAmountInput': ('交易金额面板', TransactionAmountInput, null),
      'BusinessIconBubble': ('图标展示', BusinessIcon, IconChoiceGrid),
      'IconChoiceGrid': ('图标选择网格', IconChoiceGrid, null),
      'IconCatalogPicker': ('图标目录选择', IconCatalogPicker, null),
      'SummaryMoneyText': ('自适应金额文本', SummaryMoneyText, MoneyText),
      'ComparedMoneyText': ('自适应金额文本', ComparedMoneyText, MoneyText),
      'CashflowSummaryCard': ('现金流汇总卡', CashflowSummaryCard, null),
      'AppSlidingSegmentedControl': (
        '分段控件',
        AppSlidingSegmentedControl<int>,
        null,
      ),
      'AppSurface': ('卡片', AppSurface, null),
      'Chip': ('标签', Chip, LinearProgressIndicator),
      'LinearProgressIndicator': ('进度条', LinearProgressIndicator, Chip),
      'AppPageHeader': ('页面头部', AppPageHeader, AppFormSection),
      'AppFormSection': ('表单分组', AppFormSection, null),
      'AppListSection': ('分组列表', AppListSection, null),
      'AppStatusBadge': ('状态标签', AppStatusBadge, null),
      'AppSupportingItems': ('辅助信息', AppSupportingItems, null),
      'AppListDivider': ('列表分隔线', AppListDivider, null),
    };

    String? previousTitle;
    for (final entry in examples.entries) {
      await tester.enterText(find.byType(SearchBar), entry.key);
      await tester.pump();

      final (title, componentType, excludedType) = entry.value;
      expect(find.text(title), findsOneWidget, reason: entry.key);
      if (componentType != null) {
        expect(find.byType(componentType), findsWidgets, reason: entry.key);
      }
      if (excludedType != null) {
        expect(find.byType(excludedType), findsNothing, reason: entry.key);
      }
      if (previousTitle != null && previousTitle != title) {
        expect(find.text(previousTitle), findsNothing, reason: entry.key);
      }
      expect(tester.takeException(), isNull, reason: entry.key);
      previousTitle = title;
    }
  });

  testWidgets('clears a global component search from the search bar', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSpacing');
    await tester.pump();

    expect(find.byTooltip('清除搜索'), findsOneWidget);
    expect(find.text('间距'), findsOneWidget);
    expect(find.text('色彩语义'), findsNothing);

    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pump();

    expect(find.byTooltip('清除搜索'), findsNothing);
    expect(find.text('色彩语义'), findsOneWidget);
  });

  testWidgets('opens the cascade multi-select example', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppCascadeMultiSelect');
    await tester.pumpAndSettle();
    expect(find.text('级联多选'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '打开'));
    await tester.pumpAndSettle();

    expect(find.text('选择项目'), findsOneWidget);
    expect(find.text('父级项目'), findsOneWidget);
    expect(find.text('子级项目'), findsNothing);

    await tester.tap(find.text('父级项目'));
    await tester.pump();
    expect(find.text('子级项目'), findsOneWidget);

    await tester.tap(find.text('子级项目'));
    await tester.pump();
    expect(find.text('孙级项目'), findsOneWidget);
  });

  testWidgets('opens the app date picker from the date examples', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppDatePicker');
    await tester.pumpAndSettle();
    expect(find.text('日期选择器'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '选择日期'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '选择时间'), findsNothing);
    expect(find.text('色彩语义'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, '选择日期'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDatePickerDialog), findsOneWidget);
  });

  testWidgets('selects a sample account through the account picker sheet', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AccountPlainFormRow');
    await tester.pump();

    expect(find.text('业务字段行'), findsOneWidget);
    expect(find.text('现金账户'), findsOneWidget);

    await tester.tap(find.text('现金账户'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-picker-layout-toggle')),
      findsOneWidget,
    );
    expect(find.text('选择账户'), findsNothing);
    expect(find.text('工资卡'), findsOneWidget);

    await tester.tap(find.text('工资卡'));
    await tester.pumpAndSettle();

    expect(find.text('选择账户'), findsNothing);
    expect(find.text('工资卡'), findsOneWidget);
    expect(find.text('现金账户'), findsNothing);
  });

  testWidgets('shows grouped choice grids and reports selection', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppGroupedChoiceGrid');
    await tester.pumpAndSettle();

    expect(find.text('分组选择网格'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-choice-grid-expense')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app-choice-grid-income')),
      findsOneWidget,
    );

    await tester.tap(find.text('AA'));
    await tester.pumpAndSettle();

    final grid = tester.widget<AppGroupedChoiceGrid<String>>(
      find.byType(AppGroupedChoiceGrid<String>),
    );
    expect(grid.selectedId, 'expense-aa');
  });

  testWidgets('switches category roots in the category grid picker', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'CategoryGridPicker');
    await tester.pumpAndSettle();

    expect(find.text('分类网格选择'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);

    await tester.tap(find.text('交通'));
    await tester.pumpAndSettle();

    expect(find.text('早餐'), findsNothing);
    expect(find.text('午餐'), findsNothing);
  });

  testWidgets('shows the category picker and switches root navigation', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'CategoryPickerSheet');
    await tester.pumpAndSettle();

    expect(find.text('分类分级单选'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('category-picker-root-cat-salary')),
    );
    await tester.pumpAndSettle();

    expect(find.text('基本工资'), findsOneWidget);
  });

  testWidgets('aggregates transaction badges when width is constrained', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'TransactionProgressBadges');
    await tester.pump();

    expect(find.text('交易进度徽章'), findsOneWidget);
    expect(find.byType(TransactionProgressBadges), findsNWidgets(2));
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('shows the transaction day card with daily totals', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'TransactionDayCard');
    await tester.pump();

    expect(find.text('交易日卡片'), findsOneWidget);
    expect(find.text('5月20日'), findsOneWidget);
    expect(find.byType(TransactionRow), findsNWidgets(6));
    expect(find.byType(EmptyTransactionCard), findsNothing);

    await tester.tap(find.text('餐饮'));
    await tester.pump();

    expect(find.text('打开交易详情'), findsOneWidget);
  });

  testWidgets(
    'shows the inline action button as a separate component example',
    (tester) async {
      await pumpShowcase(tester);

      await tester.enterText(find.byType(SearchBar), 'AppInlineActionButton');
      await tester.pumpAndSettle();

      expect(find.text('行内操作按钮'), findsOneWidget);
      expect(find.byType(AppInlineActionButton), findsNWidgets(2));

      await tester.tap(find.text('刷新'));
      await tester.pump();

      expect(find.text('行内操作已触发'), findsOneWidget);
    },
  );

  testWidgets('shows settings rows with a full-row select trigger', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSettingsSelectRow');
    await tester.pumpAndSettle();

    expect(find.text('设置行'), findsOneWidget);
    expect(find.text('显示余额'), findsOneWidget);
    expect(find.text('下拉灵敏度'), findsOneWidget);
    await tester.tap(find.text('下拉灵敏度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稳妥'));
    await tester.pumpAndSettle();
    expect(find.text('稳妥'), findsOneWidget);
  });

  testWidgets('shows submit button states with generic labels', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSubmitButton');
    await tester.pump();

    expect(find.text('提交按钮'), findsOneWidget);
    expect(find.byType(AppSubmitButton), findsNWidgets(4));
    expect(find.text('默认状态'), findsOneWidget);
    expect(find.text('危险操作'), findsOneWidget);
    expect(find.text('加载状态'), findsOneWidget);
    expect(find.text('禁用状态'), findsOneWidget);
    expect(find.text('主要按钮'), findsOneWidget);
    expect(find.text('危险按钮'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    expect(find.text('保存中'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '主要按钮'));
    await tester.pump();
    expect(find.text('已触发主要按钮'), findsOneWidget);
  });

  testWidgets('keeps swipe actions and message feedback separate', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSwipeAction');
    await tester.pump();

    expect(find.text('滑动操作'), findsOneWidget);
    expect(find.byType(AppSwipeAction), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '显示成功提示'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'AppStatusBanner');
    await tester.pump();

    expect(find.text('状态提示'), findsOneWidget);
    expect(find.byType(AppStatusBanner), findsNWidgets(4));
    expect(find.text('操作成功的提示文案'), findsOneWidget);
    expect(find.text('操作失败的提示文案'), findsOneWidget);
    expect(find.byType(AppSwipeAction), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'SnackBar');
    await tester.pump();

    expect(find.text('消息提示'), findsOneWidget);
    expect(find.byType(AppSwipeAction), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '显示成功提示'));
    await tester.pump();
    expect(find.text('操作成功'), findsOneWidget);
  });
}
