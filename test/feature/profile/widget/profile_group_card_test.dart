import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/token/typography.dart';
import 'package:smartflow/feature/profile/presentation/profile_menu.dart';
import 'package:smartflow/feature/profile/widget/profile_group_card.dart';

void main() {
  testWidgets('keeps five-character labels on one line', (tester) async {
    tester.view.physicalSize = const Size(340, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (final title in ['分类管理', '标签管理', '对手方管理', '摊销计划', '贷款计算器', '设置'])
        ProfileMenuEntry(title: title, iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '常用功能',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    final fiveCharacterLabel = tester.getSize(find.text('对手方管理'));
    expect(fiveCharacterLabel.height, lessThan(AppTypography.fontSizeXs * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills three grid cells with fixed-height entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (var index = 0; index < 6; index++)
        ProfileMenuEntry(title: '入口$index', iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '常用功能',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    final firstTile = tester.getRect(
      find.byKey(const ValueKey('profile-grid-entry-入口0')),
    );
    final secondTile = tester.getRect(
      find.byKey(const ValueKey('profile-grid-entry-入口1')),
    );
    const gridWidth = 340.0 - AppSpacing.space16 * 2;
    final expectedTileWidth = (gridWidth - AppSpacing.space4 * 2) / 3;

    expect(firstTile.width, closeTo(expectedTileWidth, 0.01));
    expect(firstTile.height, AppComponentTokens.profileGridTileMainExtent);
    expect(secondTile.left - firstTile.right, closeTo(AppSpacing.space4, 0.01));
    expect(firstTile.left, closeTo(AppSpacing.space16, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills cells as columns increase on wide cards', (tester) async {
    tester.view.physicalSize = const Size(560, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (var index = 0; index < 6; index++)
        ProfileMenuEntry(title: '入口$index', iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '常用功能',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    final tileCenters = [
      for (var index = 0; index < 6; index++)
        tester.getCenter(find.byKey(ValueKey('profile-grid-entry-入口$index'))),
    ];
    final firstTile = tester.getRect(
      find.byKey(const ValueKey('profile-grid-entry-入口0')),
    );
    final secondTile = tester.getRect(
      find.byKey(const ValueKey('profile-grid-entry-入口1')),
    );

    expect(tileCenters.map((center) => center.dy).toSet(), hasLength(1));
    expect(
      firstTile.width,
      closeTo(
        (560.0 - AppSpacing.space16 * 2 - AppSpacing.space4 * 5) / 6,
        0.01,
      ),
    );
    expect(secondTile.left - firstTile.right, closeTo(AppSpacing.space4, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('top-aligns labels with different line counts', (tester) async {
    tester.view.physicalSize = const Size(340, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (final title in [
        '对手方管理',
        '这是一个很长的标签名称',
        '标签管理',
        '分类管理',
        '贷款计算器',
        '设置',
      ])
        ProfileMenuEntry(title: title, iconKey: 'category', onTap: () {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: ProfileGroupCard(
              group: ProfileMenuGroup(
                title: '常用功能',
                layout: ProfileGroupLayout.grid,
                entries: entries,
              ),
            ),
          ),
        ),
      ),
    );

    final shortLabelTop = tester.getTopLeft(find.text('对手方管理')).dy;
    final longLabelTop = tester.getTopLeft(find.text('这是一个很长的标签名称')).dy;
    expect(longLabelTop, closeTo(shortLabelTop, 0.01));
    expect(
      tester.getSize(find.text('这是一个很长的标签名称')).height,
      greaterThan(tester.getSize(find.text('对手方管理')).height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses available capacity and balances 14 entries across rows', (
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
      for (var index = 0; index < 7; index++)
        tester.getCenter(find.text('入口$index')).dy,
    ];
    expect(firstRow.toSet(), hasLength(1));
    expect(
      tester.getCenter(find.text('入口7')).dy,
      greaterThan(tester.getCenter(find.text('入口0')).dy),
    );
    expect(
      tester.getCenter(find.text('入口13')).dy,
      tester.getCenter(find.text('入口7')).dy,
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
