import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_detail_summary_card.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';

void main() {
  testWidgets('surface style renders black text content in an AppSurface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppDetailSummaryCard(
          title: '2026年07月账单',
          headerTrailing: Text('已出账'),
          mainItems: [
            AppDetailSummaryCardItem(label: '账单总额', value: '100.00'),
            AppDetailSummaryCardItem(label: '待还金额', value: '80.00'),
          ],
          supportingItems: [
            AppDetailSummaryCardItem(
              label: '',
              value: '窗口覆盖 2026-06-05 至 2026-07-04',
              span: 2,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppSurface), findsOneWidget);
    expect(find.text('2026年07月账单'), findsOneWidget);
    expect(find.text('账单总额'), findsOneWidget);
    expect(find.text('待还金额'), findsOneWidget);
    expect(find.textContaining('窗口覆盖 2026-06-05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accent style renders without an AppSurface', (tester) async {
    await tester.pumpWidget(
      _app(
        const AppDetailSummaryCard(
          title: '测试账户',
          mainItems: [
            AppDetailSummaryCardItem(label: '总欠款', value: '100.00'),
            AppDetailSummaryCardItem(label: '账单欠款', value: '60.00'),
            AppDetailSummaryCardItem(label: '未归属欠款', value: '40.00'),
          ],
          supportingItems: [
            AppDetailSummaryCardItem(label: '出账日', value: '每月05日'),
            AppDetailSummaryCardItem(label: '还款日', value: '每月25日'),
          ],
          style: AppDetailSummaryCardStyle.accent,
        ),
      ),
    );

    expect(find.byType(AppSurface), findsNothing);
    expect(find.text('测试账户'), findsOneWidget);
    expect(find.text('总欠款'), findsOneWidget);
    expect(find.text('未归属欠款'), findsOneWidget);
    expect(find.text('出账日 每月05日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surface style uses accent typography and spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppDetailSummaryCard(
          title: '账单',
          mainItems: [AppDetailSummaryCardItem(label: '账单总额', value: '100.00')],
          supportingItems: [
            AppDetailSummaryCardItem(label: '起始日', value: '2026-07-01'),
          ],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('账单'));
    final label = tester.widget<Text>(find.text('账单总额'));
    final value = tester.widget<Text>(find.text('100.00'));
    final supporting = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == '起始日 2026-07-01',
      ),
    );
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w400);
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w400);
    expect(value.style?.fontSize, 18);
    expect(value.style?.fontWeight, FontWeight.w500);
    expect(supporting.text.toPlainText(), '起始日 2026-07-01');
    expect(find.byType(AppSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
