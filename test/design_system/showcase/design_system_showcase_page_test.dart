import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/showcase/design_system_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_status_banner.dart';
import 'package:smartflow/design_system/widget/app_submit_button.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/finance/cashflow_summary_card.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';
import 'package:smartflow/widget/business/icon/icon_choice_grid.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import 'package:smartflow/widget/business/transaction/transaction_progress_badges.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

const _showcaseCategoryLabels = [
  '基础规范',
  '基础组件',
  '表单组件',
  '数据展示',
  '日期组件',
  '操作与反馈',
  '财务表达',
  '交易与列表',
  '布局组件',
];

void main() {
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
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
        home: const DesignSystemShowcasePage(),
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

    for (final category in _showcaseCategoryLabels) {
      final categoryTab = find.text(category);
      await tester.ensureVisible(categoryTab);
      await tester.tap(categoryTab);
      await tester.pumpAndSettle();
      if (category == '基础组件') {
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

  testWidgets('shows the requested mobile component categories', (
    tester,
  ) async {
    await pumpShowcase(tester);

    expect(find.text('组件示例'), findsOneWidget);
    expect(find.text('搜索组件'), findsOneWidget);
    for (final category in _showcaseCategoryLabels) {
      expect(find.text(category), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches the visible examples when a category is selected', (
    tester,
  ) async {
    await pumpShowcase(tester);

    final financeCategory = find.text('财务表达');
    await tester.ensureVisible(financeCategory);
    await tester.tap(financeCategory);
    await tester.pumpAndSettle();

    expect(find.text('金额文本'), findsOneWidget);
    expect(find.text('色彩语义'), findsNothing);
  });

  testWidgets('keeps spacing and radius tokens separate', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSpacing');
    await tester.pump();

    expect(find.text('间距'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'AppSpacing',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppSurface), findsOneWidget);
    expect(find.text('圆角'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'AppRadius');
    await tester.pump();

    expect(find.text('圆角'), findsOneWidget);
    expect(find.text('间距'), findsNothing);
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

  testWidgets('searches examples across component categories', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppDatePicker');
    await tester.pumpAndSettle();

    expect(find.text('日期选择器'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '选择日期'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '选择时间'), findsNothing);
    expect(find.text('色彩语义'), findsNothing);
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
    expect(find.text('子级项目'), findsOneWidget);
  });

  testWidgets('opens the app date picker from the date examples', (
    tester,
  ) async {
    await pumpShowcase(tester);

    final dateCategory = find.text('日期组件');
    await tester.ensureVisible(dateCategory);
    await tester.tap(dateCategory);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '选择日期'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDatePickerDialog), findsOneWidget);
  });

  testWidgets('keeps financial components in separate examples', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'MoneyText');
    await tester.pump();

    expect(find.text('金额文本'), findsOneWidget);
    expect(find.text('收入状态'), findsOneWidget);
    expect(find.text('支出状态'), findsOneWidget);
    expect(find.text('中性状态'), findsOneWidget);
    expect(find.byType(MoneyText), findsWidgets);
    expect(find.byType(AccountTypeTag), findsNothing);
    expect(find.byType(TransactionPurposeBadge), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'AccountTypeTag');
    await tester.pump();

    expect(find.text('账户类型标签'), findsOneWidget);
    expect(find.byType(AccountTypeTag), findsWidgets);
    expect(find.byType(MoneyText), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'TransactionPurposeBadge');
    await tester.pump();

    expect(find.text('交易用途标签'), findsOneWidget);
    expect(find.byType(TransactionPurposeBadge), findsWidgets);
    expect(find.byType(MoneyText), findsNothing);
    expect(find.byType(AccountTypeTag), findsNothing);
  });

  testWidgets('keeps transaction rows and empty states separate', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'TransactionRow');
    await tester.pump();

    expect(find.text('交易行'), findsOneWidget);
    expect(find.byType(TransactionRow), findsWidgets);
    expect(find.byType(EmptyTransactionCard), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'EmptyTransactionCard');
    await tester.pump();

    expect(find.text('空状态'), findsOneWidget);
    expect(find.byType(EmptyTransactionCard), findsOneWidget);
    expect(find.byType(TransactionRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps row-form and submit components separate', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppPlainTextFormRow');
    await tester.pump();

    expect(find.text('文本输入行'), findsOneWidget);
    expect(find.byType(AppPlainTextFormRow), findsWidgets);
    expect(find.byType(AppSubmitButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covers required, read-only and error states for text rows', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppPlainTextFormRow');
    await tester.pump();

    expect(find.text('必填状态'), findsOneWidget);
    expect(find.text('*'), findsOneWidget);
    expect(find.text('带必填标识与辅助说明'), findsOneWidget);
    expect(find.text('只读状态'), findsOneWidget);
    expect(find.text('输入错误'), findsOneWidget);
    expect(find.text('禁用状态'), findsOneWidget);
  });

  testWidgets('keeps money form rows separate from text form rows', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'MoneyPlainFormRow');
    await tester.pump();

    expect(find.text('金额输入行'), findsOneWidget);
    expect(find.byType(MoneyPlainFormRow), findsNWidgets(2));
    expect(find.text('仅允许数字与两位小数'), findsOneWidget);
    expect(find.text('文本输入行'), findsNothing);
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

    expect(find.text('选择账户'), findsOneWidget);
    expect(find.text('工资卡'), findsOneWidget);

    await tester.tap(find.text('工资卡'));
    await tester.pumpAndSettle();

    expect(find.text('选择账户'), findsNothing);
    expect(find.text('工资卡'), findsOneWidget);
    expect(find.text('现金账户'), findsNothing);
  });

  testWidgets('shows the transaction amount panel with expense semantics', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'TransactionAmountInput');
    await tester.pump();

    expect(find.text('交易金额面板'), findsOneWidget);
    expect(find.byType(TransactionAmountInput), findsOneWidget);
    expect(find.text('¥'), findsOneWidget);
  });

  testWidgets('keeps business icons separate from the icon choice grid', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'BusinessIconBubble');
    await tester.pumpAndSettle();

    expect(find.text('业务图标'), findsOneWidget);
    expect(find.byType(BusinessIcon), findsWidgets);
    expect(find.byType(IconChoiceGrid), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'IconChoiceGrid');
    await tester.pumpAndSettle();

    expect(find.text('图标选择网格'), findsOneWidget);
    expect(find.byType(IconChoiceGrid), findsOneWidget);
    expect(find.text('业务图标'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'IconCatalogPicker');
    await tester.pumpAndSettle();

    expect(find.text('图标目录选择'), findsOneWidget);
    expect(find.byType(IconCatalogPicker), findsOneWidget);
    expect(find.byType(IconChoiceGrid), findsOneWidget);
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

  testWidgets('keeps adaptive money text separate from money text', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'SummaryMoneyText');
    await tester.pump();

    expect(find.text('自适应金额文本'), findsOneWidget);
    expect(find.byType(SummaryMoneyText), findsNWidgets(2));
    expect(find.byType(ComparedMoneyText), findsOneWidget);
    expect(find.byType(MoneyText), findsNothing);
  });

  testWidgets('keeps the cashflow summary card in its own example', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'CashflowSummaryCard');
    await tester.pump();

    expect(find.text('现金流汇总卡'), findsOneWidget);
    expect(find.byType(CashflowSummaryCard), findsNWidgets(2));
    expect(find.text('本月收入'), findsNWidgets(2));
    expect(find.text('+1.2千/18%/12%'), findsOneWidget);
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
    expect(find.byType(TransactionRow), findsNWidgets(2));
    expect(find.byType(EmptyTransactionCard), findsNothing);

    await tester.tap(find.text('餐饮'));
    await tester.pump();

    expect(find.text('打开交易详情'), findsOneWidget);
  });

  testWidgets('uses tabs and separates buttons from segmented controls', (
    tester,
  ) async {
    await pumpShowcase(tester);

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('基础组件'));
    await tester.pump();

    expect(find.text('按钮'), findsOneWidget);
    expect(find.text('分段控件'), findsOneWidget);
    expect(find.text('按钮与分段控件'), findsNothing);
    expect(find.byType(AppSegmentedControl<int>), findsOneWidget);
    expect(find.byType(AppSlidingSegmentedControl<int>), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '主要按钮'), findsOneWidget);
  });

  testWidgets('uses generic content in the card component example', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppSurface');
    await tester.pumpAndSettle();

    expect(find.text('卡片'), findsOneWidget);
    expect(find.text('卡片标题'), findsOneWidget);
    expect(find.text('这是卡片的描述文案'), findsOneWidget);
    expect(find.text('微信钱包'), findsNothing);
    expect(find.byType(AppSurface), findsNWidgets(2));
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

  testWidgets('keeps labels and progress indicators separate', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'Chip');
    await tester.pump();

    expect(find.text('标签'), findsOneWidget);
    expect(find.text('默认标签'), findsOneWidget);
    expect(find.text('成功标签'), findsOneWidget);
    expect(find.text('警告标签'), findsOneWidget);
    expect(find.byType(Chip), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'LinearProgressIndicator');
    await tester.pump();

    expect(find.text('进度条'), findsOneWidget);
    expect(find.text('默认 60%'), findsOneWidget);
    expect(find.text('成功 30%'), findsOneWidget);
    expect(find.text('警告 80%'), findsOneWidget);
    expect(find.text('危险 50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('keeps page headers and form sections separate', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), 'AppPageHeader');
    await tester.pump();

    expect(find.text('页面标题'), findsOneWidget);
    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(find.byType(AppFormSection), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'AppFormSection');
    await tester.pump();

    expect(find.text('表单分组'), findsOneWidget);
    expect(find.byType(AppFormSection), findsOneWidget);
    expect(find.byType(AppPageHeader), findsNothing);
    expect(tester.takeException(), isNull);
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
