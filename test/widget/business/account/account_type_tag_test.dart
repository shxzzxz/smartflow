import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/widget/business/account/account_type_tag.dart';
import 'package:smartflow/widget/business/finance/finance_dot_label.dart';

void main() {
  testWidgets('maps account type and subtype to the shared dot label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AccountTypeTag(
            type: AccountType.asset,
            subtype: AccountSubtype.fund,
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(AccountTypeTag));
    final color = Theme.of(context).extension<AppThemeExtension>()!.asset;
    final dotLabel = tester.widget<FinanceDotLabel>(
      find.byType(FinanceDotLabel),
    );

    expect(find.text('资金账户'), findsOneWidget);
    expect(dotLabel.dotColor, color);
  });

  testWidgets('maps a non-asset account type to its finance color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AccountTypeTag(type: AccountType.liability)),
      ),
    );

    final context = tester.element(find.byType(AccountTypeTag));
    final color = Theme.of(context).extension<AppThemeExtension>()!.liability;
    final dotLabel = tester.widget<FinanceDotLabel>(
      find.byType(FinanceDotLabel),
    );

    expect(find.text('负债'), findsOneWidget);
    expect(dotLabel.dotColor, color);
  });
}
