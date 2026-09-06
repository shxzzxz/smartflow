import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';

void main() {
  testWidgets('keeps a section action beside a wrapping title', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SizedBox(
              width: 320,
              child: AppFormSection(
                title: '较长的分组标题与操作',
                trailing: TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('删除'),
                ),
                children: const [Text('字段')],
              ),
            ),
          ),
        ),
      ),
    );
    final title = tester.getCenter(find.text('较长的分组标题与操作'));
    final button = tester.getCenter(find.byType(TextButton));
    expect(button.dy, closeTo(title.dy, 1));
    expect(button.dx, greaterThan(title.dx));
    await tester.tap(find.byType(TextButton));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact spacing between form rows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppFormSection(
            children: [
              SizedBox(key: Key('first-row'), height: 10),
              SizedBox(key: Key('second-row'), height: 10),
            ],
          ),
        ),
      ),
    );

    final firstBottom = tester.getBottomLeft(
      find.byKey(const Key('first-row')),
    );
    final secondTop = tester.getTopLeft(find.byKey(const Key('second-row')));

    expect(secondTop.dy - firstBottom.dy, 4);
  });

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
