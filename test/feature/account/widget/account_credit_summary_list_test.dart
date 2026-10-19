import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/feature/account/widget/account_credit_summary_list.dart';
import 'package:smartflow/widget/business/finance/finance_summary_row.dart';

void main() {
  testWidgets('renders supporting items, semantic status, and no chevron', (
    tester,
  ) async {
    var tapped = false;
    const presentation = FinanceSummaryRowPresentation(
      id: 'summary',
      title: '2026年07月',
      amount: Money(minorUnits: 320000),
      supportingTexts: [
        AppSupportingText('到期 07-25'),
        AppSupportingText('12 条明细'),
      ],
      status: AppStatusBadgePresentation(
        label: '已出账',
        tone: AppStatusTone.warning,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AccountCreditSummaryList(
            items: const [presentation],
            emptyMessage: '暂无数据',
            onTap: (_) => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('2026年07月'), findsOneWidget);
    expect(find.text('到期 07-25'), findsOneWidget);
    expect(find.text('12 条明细'), findsOneWidget);
    expect(find.text('3200.00'), findsOneWidget);
    expect(find.byIcon(RemixIcons.arrow_right_s_line), findsNothing);

    final context = tester.element(find.text('已出账'));
    final warning = Theme.of(context).extension<AppThemeExtension>()!.warning;
    final statusText = tester.widget<Text>(find.text('已出账'));
    expect(statusText.style?.color, warning);
    final amountText = tester.widget<Text>(find.text('3200.00'));
    expect(
      amountText.style?.color,
      Theme.of(context).extension<AppThemeExtension>()!.liability,
    );

    await tester.tap(find.text('2026年07月'));
    expect(tapped, isTrue);
  });
}
