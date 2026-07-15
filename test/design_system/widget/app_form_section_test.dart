import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';

void main() {
  testWidgets('renders section hierarchy without row dividers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppFormSection(
            title: '基本信息',
            description: '用于日常展示和记账',
            children: [Text('账户名称'), Text('备注')],
          ),
        ),
      ),
    );

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('用于日常展示和记账'), findsOneWidget);
    expect(find.text('账户名称'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });
}
