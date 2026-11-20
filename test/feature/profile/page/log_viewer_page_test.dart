import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/application/shared/app_appearance_settings.dart';
import 'package:smartflow/core/logging/app_log_reader.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/feature/profile/page/log_viewer_page.dart';
import 'package:smartflow/feature/profile/view_model/log_viewer_view_model.dart';

void main() {
  for (final config in [
    (width: 320.0, dark: false, style: AppHeaderStyle.frostedGlass, scale: 1.0),
    (width: 320.0, dark: true, style: AppHeaderStyle.classic, scale: 1.5),
    (width: 1200.0, dark: false, style: AppHeaderStyle.classic, scale: 1.0),
    (width: 390.0, dark: true, style: AppHeaderStyle.frostedGlass, scale: 1.5),
  ]) {
    testWidgets('full width log header and inset card for $config', (
      tester,
    ) async {
      final appearance = AppAppearanceSettings(headerStyle: config.style);
      await _pumpLogs(
        tester,
        width: config.width,
        scale: config.scale,
        theme: config.dark
            ? AppTheme.dark(appearance: appearance)
            : AppTheme.light(appearance: appearance),
      );

      final header = tester.getRect(find.byType(AppPageHeader));
      expect(header.left, 0);
      expect(header.width, config.width);
      expect(header.top, 24);
      expect(tester.getCenter(find.text('日志')).dx, config.width / 2);
      final card = tester.getRect(find.byType(AppSurface));
      expect(card.left, 16);
      expect(card.right, config.width - 16);
      expect(card.top, greaterThan(header.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('card retains filtering, empty feedback and entry details', (
    tester,
  ) async {
    await _pumpLogs(tester);
    await tester.enterText(find.byType(TextField), '没有结果');
    await tester.pump();
    expect(find.text('没有匹配的日志'), findsOneWidget);
    expect(find.byType(AppSurface), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('错误'));
    await tester.pumpAndSettle();
    expect(find.text('应用已启动'), findsNothing);
    expect(find.text('读取失败'), findsOneWidget);

    await tester.tap(find.text('读取失败'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('复制日志'), findsOneWidget);
    expect(find.text('调用栈'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLogs(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        logEntriesProvider.overrideWith(
          (ref) async => [
            AppLogEntry(
              time: DateTime.utc(2026, 1, 15, 8),
              level: Level.INFO,
              loggerName: 'app.bootstrap',
              message: '应用已启动',
            ),
            AppLogEntry(
              time: DateTime.utc(2026, 1, 15, 9),
              level: Level.SEVERE,
              loggerName: 'app.test',
              message: '读取失败',
              error: 'TestException',
              stackTrace: '#0 testRead',
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const LogViewerPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
