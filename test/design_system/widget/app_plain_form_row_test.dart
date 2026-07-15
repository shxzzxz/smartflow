import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';

void main() {
  testWidgets('shows required label and supporting text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPlainFormRow(
            label: '账户名称',
            requiredIndicator: true,
            supportingText: '用于账单和统计展示',
            child: Text('工资卡'),
          ),
        ),
      ),
    );

    expect(find.text('账户名称'), findsOneWidget);
    expect(find.text('*'), findsOneWidget);
    expect(find.text('用于账单和统计展示'), findsOneWidget);
  });

  testWidgets('error replaces supporting text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPlainFormRow(
            label: '账户名称',
            supportingText: '用于账单和统计展示',
            errorText: '请输入账户名称',
            child: Text(''),
          ),
        ),
      ),
    );

    expect(find.text('请输入账户名称'), findsOneWidget);
    expect(find.text('用于账单和统计展示'), findsNothing);
  });

  testWidgets('disabled row does not invoke tap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPlainFormRow(
            label: '账户',
            enabled: false,
            onTap: () => taps++,
            child: const Text('现金'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('现金'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('disabled value row forwards the disabled state', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPlainValueRow(
            label: '账户',
            value: '现金',
            enabled: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(Opacity), findsOneWidget);
    await tester.tap(find.text('现金'), warnIfMissed: false);
    expect(taps, 0);
  });
}
