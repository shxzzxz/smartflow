import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/transaction/transaction_day_card.dart';

void main() {
  testWidgets('preserves negative daily expense totals for refunds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionDayCard(
            group: TransactionDayGroup(
              date: DateTime(2026, 7, 22),
              rows: const [],
              incomeMinor: 0,
              expenseMinor: -3000,
            ),
          ),
        ),
      ),
    );

    expect(find.text('-30'), findsOneWidget);
    expect(find.text('30'), findsNothing);
  });
}
