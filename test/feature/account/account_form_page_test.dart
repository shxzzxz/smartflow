import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/account/page/account_form_page.dart';

void main() {
  testWidgets('loan account form shows 初始欠款 / 信用额度 / 还款日 without billing day', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountFormPage(),
        ),
      ),
    );

    await tester.tap(find.text('贷款'));
    await tester.pump();

    expect(find.text('初始欠款'), findsOneWidget);
    expect(find.text('信用额度'), findsOneWidget);
    expect(find.text('还款日'), findsWidgets);
    expect(find.text('出账还款日'), findsNothing);
    expect(find.text('出账日'), findsNothing);
  });
}
