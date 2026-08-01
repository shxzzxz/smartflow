import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows profile actions and debug tools in purpose groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ProfilePage()),
    );
    await tester.pump();

    expect(find.text('账务管理'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('帮助与关于'), findsOneWidget);
    expect(find.text('开发工具'), findsOneWidget);

    final sections = find.byType(AppSurface);
    expect(sections, findsNWidgets(5));
    expect(
      find.descendant(of: sections.at(0), matching: find.text('分类管理')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(0), matching: find.text('账户管理')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(1), matching: find.text('数据导入')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(1), matching: find.text('数据清理')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(2), matching: find.text('界面设置')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(3), matching: find.text('使用说明')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(3), matching: find.text('软件版本')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(4), matching: find.text('组件示例')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
