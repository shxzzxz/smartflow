import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/finance/finance_activity_row.dart';
import 'package:smartflow/widget/business/finance/finance_schedule_list.dart';

void main() {
  testWidgets('financial schedule row renders shared status and opens detail', (
    tester,
  ) async {
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
  });

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
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SizedBox(width: 360, child: child)),
  );
}
