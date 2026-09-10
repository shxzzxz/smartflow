import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/feature/profile/page/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const updateChannel = MethodChannel('com.shxzz.smartflow/app_update');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          if (call.method == 'getVersionInfo') {
            return <String, Object?>{
              'versionName': '0.5.1-dev.2',
              'buildNumber': 47,
            };
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, null);
  });

  testWidgets('shows shortcuts and grouped actions with working destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const destinations = {
      '分类管理': '/category',
      '标签管理': '/tags',
      '贷款计算器': '/profile/loan-calculator',
      '设置': '/profile/settings',
      '分期产品': '/installment-products',
      '参考利率': '/profile/reference-rates',
      '数据导入': '/profile/import',
      '数据清理': '/profile/data-cleanup',
      '数据备份': '/profile/backup',
      '使用手册': '/profile/manual',
      '软件版本': '/profile/software-version',
      '组件示例': '/dev/design-system',
      '日志': '/dev/logs',
    };
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        for (final path in destinations.values)
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(body: Text('目标页面：$path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    for (final title in ['常用功能', '账务管理', '数据管理', '偏好设置', '帮助与关于', '开发工具']) {
      expect(find.text(title), findsNothing);
    }

    final sections = find.byType(AppSurface);
    expect(sections, findsNWidgets(5));
    const groups = [
      ['分类管理', '标签管理', '贷款计算器', '设置'],
      ['分期产品', '参考利率'],
      ['数据导入', '数据清理', '数据备份'],
      ['使用手册', '软件版本'],
      ['组件示例', '日志'],
    ];
    for (var index = 0; index < groups.length; index++) {
      for (final label in groups[index]) {
        expect(
          find.descendant(of: sections.at(index), matching: find.text(label)),
          findsOneWidget,
        );
      }
    }
    expect(find.text('账户管理'), findsNothing);
    final shortcutPositions = [
      for (final label in groups.first) tester.getCenter(find.text(label)),
    ];
    for (var index = 1; index < shortcutPositions.length; index++) {
      expect(shortcutPositions[index].dy, shortcutPositions.first.dy);
      expect(
        shortcutPositions[index].dx,
        greaterThan(shortcutPositions[index - 1].dx),
      );
    }
    expect(find.text('0.5.1-dev.2'), findsOneWidget);
    expect(
      tester.getCenter(find.text('0.5.1-dev.2')).dx,
      greaterThan(tester.getCenter(find.text('软件版本')).dx),
    );
    expect(
      tester.getCenter(find.text('0.5.1-dev.2')).dy,
      tester.getCenter(find.text('软件版本')).dy,
    );
    expect(tester.takeException(), isNull);

    for (final destination in destinations.entries) {
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(find.text('目标页面：${destination.value}'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
  });
}
