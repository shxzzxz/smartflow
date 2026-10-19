import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';
import 'package:smartflow/design_system/widget/app_list_section.dart';
import 'package:smartflow/design_system/widget/app_section_header.dart';

void main() {
  testWidgets('renders a header and dividers between rows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppListSection(
            header: AppSectionHeader(title: '界面设置'),
            children: [Text('第一行'), Text('第二行'), Text('第三行')],
          ),
        ),
      ),
    );

    expect(find.text('界面设置'), findsOneWidget);
    expect(find.text('第一行'), findsOneWidget);
    expect(find.text('第二行'), findsOneWidget);
    expect(find.text('第三行'), findsOneWidget);
    expect(find.byType(AppListDivider), findsNWidgets(2));
  });

  testWidgets('does not add dividers for an empty list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppListSection(children: [])),
      ),
    );

    expect(find.byType(AppListDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
