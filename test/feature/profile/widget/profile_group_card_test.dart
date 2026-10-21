import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/presentation/profile_menu.dart';
import 'package:smartflow/feature/profile/widget/profile_group_card.dart';

void main() {
  testWidgets('renders a 14-entry grid as five columns and three rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (var index = 0; index < 14; index++)
        ProfileMenuEntry(title: '入口$index', iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '测试分组',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    final firstRow = [
      for (var index = 0; index < 5; index++)
        tester.getCenter(find.text('入口$index')).dy,
    ];
    expect(firstRow.toSet(), hasLength(1));
    expect(
      tester.getCenter(find.text('入口13')).dy,
      greaterThan(tester.getCenter(find.text('入口9')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders list values and invokes entry callbacks', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ProfileGroupCard(
            group: ProfileMenuGroup(
              title: '帮助与关于',
              layout: ProfileGroupLayout.list,
              entries: [
                ProfileMenuEntry(
                  title: '软件版本',
                  value: '1.2.3',
                  iconKey: 'version',
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('帮助与关于'), findsOneWidget);
    expect(find.text('1.2.3'), findsOneWidget);
    await tester.tap(find.text('软件版本'));
    expect(tapped, isTrue);
  });

  testWidgets('reduces grid columns for large text without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (var index = 0; index < 14; index++)
        ProfileMenuEntry(title: '入口$index', iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '测试分组',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.text('入口2')).dy,
      tester.getCenter(find.text('入口0')).dy,
    );
    expect(
      tester.getCenter(find.text('入口3')).dy,
      greaterThan(tester.getCenter(find.text('入口0')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
