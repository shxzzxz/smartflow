import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/widget/business/finance/bill_item_row.dart';
import 'package:smartflow/widget/business/finance/finance_activity_row.dart';
import 'package:smartflow/widget/business/finance/finance_schedule_list.dart';
import 'package:smartflow/widget/business/finance/finance_summary_row.dart';

void main() {
  group('Finance detail rows', () {
    testWidgets(
      'financial schedule row renders shared status and opens detail',
      (tester) async {
        var opened = false;
        await tester.pumpWidget(
          _app(
            FinanceScheduleList(
              items: [
                FinanceScheduleItem(
                  id: 'period-1',
                  periodLabel: '01',
                  date: DateTime(2026, 1, 31),
                  amountLabel: '100.00',
                  statusLabel: '已确认',
                  statusTone: FinanceScheduleTone.success,
                  onTap: () => opened = true,
                ),
              ],
            ),
          ),
        );

        expect(find.text('01'), findsOneWidget);
        expect(find.text('100.00'), findsOneWidget);
        expect(find.text('已确认'), findsOneWidget);
        await tester.tap(find.text('01'));

        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'financial activity row renders shared content and opens detail',
      (tester) async {
        var opened = false;
        await tester.pumpWidget(
          _app(
            FinanceActivityRow(
              label: '摊销退款',
              occurredAt: DateTime(2026, 2, 1),
              supportingText: '退回现金账户',
              amountLabel: '50.00',
              icon: RemixIcons.refund_2_line,
              onTap: () => opened = true,
            ),
          ),
        );

        expect(find.textContaining('摊销退款'), findsOneWidget);
        expect(find.text('退回现金账户'), findsOneWidget);
        expect(find.text('50.00'), findsOneWidget);
        await tester.tap(find.textContaining('摊销退款'));

        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'activity rows preserve annual and monthly periods when opened',
      (tester) async {
        final opened = <String>[];
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                for (final period in ['2026年', '2026年11月'])
                  FinanceActivityRow.period(
                    label: '缴费',
                    periodLabel: period,
                    amountLabel: '1200',
                    icon: RemixIcons.bank_card_line,
                    onTap: () => opened.add(period),
                  ),
              ],
            ),
          ),
        );
        expect(find.text('缴费 · 2026年'), findsOneWidget);
        expect(find.text('缴费 · 2026年11月'), findsOneWidget);
        await tester.tap(find.text('缴费 · 2026年'));
        await tester.tap(find.text('缴费 · 2026年11月'));
        expect(opened, ['2026年', '2026年11月']);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FinanceSummaryRow', () {
    testWidgets('renders status badge below the financial amount', (
      tester,
    ) async {
      var tapped = false;
      const presentation = FinanceSummaryRowPresentation(
        id: 'bill-1',
        title: '信用卡',
        amount: Money(minorUnits: 320000),
        supportingTexts: [AppSupportingText('2 条明细')],
        status: AppStatusBadgePresentation(
          label: '已出账',
          tone: AppStatusTone.warning,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FinanceSummaryRow(
              presentation: presentation,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('信用卡'), findsOneWidget);
      expect(find.text('2 条明细'), findsOneWidget);
      expect(find.text('3200.00'), findsOneWidget);
      expect(find.text('已出账'), findsOneWidget);

      final amountRect = tester.getRect(find.text('3200.00'));
      final statusRect = tester.getRect(find.text('已出账'));
      expect(statusRect.top, greaterThan(amountRect.bottom));

      final context = tester.element(find.text('已出账'));
      final warning = Theme.of(context).extension<AppThemeExtension>()!.warning;
      expect(tester.widget<Text>(find.text('已出账')).style?.color, warning);

      await tester.tap(find.text('信用卡'));
      expect(tapped, isTrue);
    });

    testWidgets('supports amount label and optional chevron', (tester) async {
      var tapped = false;
      const presentation = FinanceSummaryRowPresentation(
        id: 'bill-2',
        title: '招商银行',
        amount: Money(minorUnits: 0),
        amountLabel: '待计算',
        supportingTexts: [AppSupportingText('3 条明细')],
        status: AppStatusBadgePresentation(
          label: '未出账',
          tone: AppStatusTone.neutral,
        ),
        showChevron: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FinanceSummaryRow(
              presentation: presentation,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('待计算'), findsOneWidget);
      expect(find.byIcon(RemixIcons.arrow_right_s_line), findsOneWidget);

      await tester.tap(find.text('招商银行'));
      expect(tapped, isTrue);
    });
  });

  group('BillItemRow', () {
    testWidgets('renders the status badge below the item amount', (
      tester,
    ) async {
      var tapped = false;
      const presentation = BillItemRowPresentation(
        id: 'item-1',
        leadingIcon: Icons.receipt_long,
        title: '消费',
        supportingTexts: [AppSupportingText('还款 2026-07-20')],
        amount: Money(minorUnits: 7550),
        status: AppStatusBadgePresentation(
          label: '部分已还',
          tone: AppStatusTone.warning,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BillItemRow(
              presentation: presentation,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('消费'), findsOneWidget);
      expect(find.text('还款 2026-07-20'), findsOneWidget);
      expect(find.text('75.50'), findsOneWidget);
      expect(find.text('部分已还'), findsOneWidget);

      final amountRect = tester.getRect(find.text('75.50'));
      final statusRect = tester.getRect(find.text('部分已还'));
      expect(statusRect.top, greaterThan(amountRect.bottom));

      await tester.tap(find.text('消费'));
      expect(tapped, isTrue);
    });
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SizedBox(width: 360, child: child)),
  );
}
