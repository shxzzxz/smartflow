import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/widget/business/finance/finance_dot_label.dart';
import 'package:smartflow/widget/business/transaction/transaction_purpose_badge.dart';

void main() {
  testWidgets('keeps purpose text and color mapping in the business wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TransactionPurposeBadge(purpose: BusinessPurpose.dailyExpense),
        ),
      ),
    );

    final context = tester.element(find.byType(TransactionPurposeBadge));
    final color = Theme.of(context).extension<AppThemeExtension>()!.expense;
    final dotLabel = tester.widget<FinanceDotLabel>(
      find.byType(FinanceDotLabel),
    );

    expect(find.text('支出'), findsOneWidget);
    expect(dotLabel.dotColor, color);
  });

  testWidgets('maps other purposes to the info color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TransactionPurposeBadge(purpose: BusinessPurpose.refund),
        ),
      ),
    );

    final context = tester.element(find.byType(TransactionPurposeBadge));
    final color = Theme.of(context).extension<AppThemeExtension>()!.info;
    final dotLabel = tester.widget<FinanceDotLabel>(
      find.byType(FinanceDotLabel),
    );

    expect(find.text('退款'), findsOneWidget);
    expect(dotLabel.dotColor, color);
  });
}
