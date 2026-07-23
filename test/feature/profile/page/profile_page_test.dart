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

  testWidgets('shows profile actions in three purpose groups', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ProfilePage()),
    );
    await tester.pump();

    expect(find.text('账务管理'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('帮助与关于'), findsOneWidget);

    final sections = find.byType(AppSurface);
    expect(sections, findsNWidgets(3));
    expect(
      find.descendant(of: sections.at(0), matching: find.text('分类管理')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(0), matching: find.text('账户管理')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(1), matching: find.text('一木记账导入')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(2), matching: find.text('使用说明')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sections.at(2), matching: find.text('软件版本')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
