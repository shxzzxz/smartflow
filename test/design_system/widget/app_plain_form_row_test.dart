import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';

void main() {
  testWidgets('keeps form labels close in size to field values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPlainFormRow(
            label: '本金',
            child: AppPlainValueText(text: '10000.00'),
          ),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('本金'));
    final value = tester.widget<Text>(find.text('10000.00'));

    expect(label.style!.fontSize, 14);
    expect(value.style!.fontSize, 15);
  });

  testWidgets('uses compact touch-safe height for a plain row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AppPlainFormRow(
                key: Key('plain-row'),
                label: '账户',
                child: Text('现金'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('plain-row'))).height, 48);
  });

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

  testWidgets('read-only value rows keep values right aligned', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppPlainValueRow(label: '账户', value: '现金')),
      ),
    );

    expect(tester.widget<Text>(find.text('现金')).textAlign, TextAlign.right);
  });

  testWidgets('switch row shows optional description with weaker hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: Column(
                children: [
                  const AppPlainFormRow(label: '账户', child: Text('现金')),
                  AppPlainSwitchRow(
                    key: const Key('described-switch'),
                    label: '创建放款交易',
                    description: '迁移已有贷款时可关闭，仅创建合同和还款计划',
                    value: true,
                    onChanged: (_) {},
                  ),
                  AppPlainSwitchRow(
                    key: const Key('plain-switch'),
                    label: '参与统计',
                    value: false,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final plainLabel = tester.widget<Text>(find.text('账户'));
    final label = tester.widget<Text>(find.text('创建放款交易'));
    final description = tester.widget<Text>(find.text('迁移已有贷款时可关闭，仅创建合同和还款计划'));

    expect(label.style, plainLabel.style);
    expect(label.style!.fontSize, greaterThan(description.style!.fontSize!));
    expect(label.style!.color, isNot(description.style!.color));
    expect(
      tester.getSize(find.byKey(const Key('described-switch'))).height,
      greaterThan(tester.getSize(find.byKey(const Key('plain-switch'))).height),
    );
    expect(tester.getSize(find.byKey(const Key('plain-switch'))).height, 48);
    expect(find.text('参与统计'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('disabled switch row does not invoke change callback', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPlainSwitchRow(
            label: '参与统计',
            value: false,
            enabled: false,
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.tap(find.text('参与统计'));
    expect(changes, 0);
  });

  testWidgets('switch row restores its controlled value on Form reset', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: AppPlainSwitchRow(
                  label: '参与统计',
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('参与统计'));
    await tester.pump();
    expect(value, true);

    formKey.currentState!.reset();
    await tester.pump();

    expect(value, false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });
}
