import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_section_header.dart';

void main() {
  testWidgets('renders title, subtitle, and trailing action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSectionHeader(
            title: '界面设置',
            subtitle: '控制应用的基础显示行为',
            trailing: TextButton(
              onPressed: () => tapped = true,
              child: const Text('重置'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('界面设置'), findsOneWidget);
    expect(find.text('控制应用的基础显示行为'), findsOneWidget);

    await tester.tap(find.text('重置'));
    expect(tapped, isTrue);
  });

  testWidgets('keeps an action beside a wrapping title at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const SizedBox(
              width: 320,
              child: AppSectionHeader(
                title: '较长的分组标题与操作',
                trailing: Text('2 项'),
              ),
            ),
          ),
        ),
      ),
    );

    final title = tester.getCenter(find.text('较长的分组标题与操作'));
    final trailing = tester.getCenter(find.text('2 项'));
    expect(trailing.dy, closeTo(title.dy, 1));
    expect(trailing.dx, greaterThan(title.dx));
    expect(tester.takeException(), isNull);
  });
}
