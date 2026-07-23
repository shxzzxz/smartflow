import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/showcase/design_system_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_submit_button.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

void main() {
  Future<void> pumpShowcase(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const DesignSystemShowcasePage(),
      ),
    );
  }

  testWidgets('shows the requested mobile component categories', (
    tester,
  ) async {
    await pumpShowcase(tester);

    expect(find.text('组件示例'), findsOneWidget);
    expect(find.text('搜索组件'), findsOneWidget);
    for (final category in const [
      '基础规范',
      '基础组件',
      '表单组件',
      '数据展示',
      '日期组件',
      '操作与反馈',
      '财务表达',
      '交易与列表',
      '布局组件',
    ]) {
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

    expect(find.text('金额语义'), findsOneWidget);
    expect(find.text('色彩语义'), findsNothing);
  });

  testWidgets('searches examples across component categories', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(find.byType(SearchBar), '日期');
    await tester.pumpAndSettle();

    expect(find.text('日期与时间选择'), findsOneWidget);
    expect(find.text('色彩语义'), findsNothing);
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

  testWidgets('shows the financial semantic components together', (
    tester,
  ) async {
    await pumpShowcase(tester);

    final financeCategory = find.text('财务表达');
    await tester.ensureVisible(financeCategory);
    await tester.tap(financeCategory);
    await tester.pumpAndSettle();

    expect(find.byType(MoneyText), findsWidgets);
    expect(find.byType(AccountTypeTag), findsWidgets);
    expect(find.byType(TransactionPurposeBadge), findsWidgets);
  });

  testWidgets('reuses transaction row and empty-state components', (
    tester,
  ) async {
    await pumpShowcase(tester);

    final transactionCategory = find.text('交易与列表');
    await tester.ensureVisible(transactionCategory);
    await tester.tap(transactionCategory);
    await tester.pumpAndSettle();

    expect(find.byType(TransactionRow), findsWidgets);
    expect(find.byType(EmptyTransactionCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses the row-form and submit components', (tester) async {
    await pumpShowcase(tester);

    final formCategory = find.text('表单组件');
    await tester.ensureVisible(formCategory);
    await tester.tap(formCategory);
    await tester.pump();

    expect(find.byType(AppPlainTextFormRow), findsWidgets);
    expect(find.byType(AppSubmitButton), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the app segmented control with base buttons', (
    tester,
  ) async {
    await pumpShowcase(tester);

    await tester.tap(find.text('基础组件'));
    await tester.pump();

    expect(find.byType(AppSegmentedControl<int>), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '主要按钮'), findsOneWidget);
  });

  testWidgets('shows the app page header and form-section layout', (
    tester,
  ) async {
    await pumpShowcase(tester);

    final layoutCategory = find.text('布局组件');
    await tester.ensureVisible(layoutCategory);
    await tester.tap(layoutCategory);
    await tester.pump();

    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(find.byType(AppFormSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows swipe actions and interactive feedback', (tester) async {
    await pumpShowcase(tester);

    final feedbackCategory = find.text('操作与反馈');
    await tester.ensureVisible(feedbackCategory);
    await tester.tap(feedbackCategory);
    await tester.pump();

    expect(find.byType(AppSwipeAction), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '显示成功提示'));
    await tester.pump();
    expect(find.text('操作成功'), findsOneWidget);
  });
}
