import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'manual_test_assets.dart';
import 'package:smartflow/feature/profile/page/manual_article_page.dart';
import 'package:smartflow/feature/profile/page/manual_page.dart';

void main() {
  setUp(mockManualAssets);
  tearDown(clearManualAssetsMock);

  Future<void> pumpManualPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _manualRouter(),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows subtitle, search and grouped article sections', (
    tester,
  ) async {
    await pumpManualPage(tester);

    expect(find.text('使用手册'), findsOneWidget);
    expect(find.text('从记录第一笔账开始，逐步理解账户、交易和信贷功能。'), findsOneWidget);
    expect(find.text('搜索手册'), findsOneWidget);

    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('账务基础'), findsOneWidget);
    expect(find.text('信贷与分期'), findsOneWidget);
    expect(find.text('2 篇'), findsOneWidget);
    expect(find.text('1 篇'), findsOneWidget);
    expect(find.text('4 篇'), findsOneWidget);

    expect(find.text('SmartFlow 的记账方式'), findsOneWidget);
    expect(find.text('计息方式和关键指标'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters articles across categories', (tester) async {
    await pumpManualPage(tester);

    await tester.enterText(find.byType(TextField), 'IRR');
    await tester.pump();

    expect(find.text('计息方式和关键指标'), findsOneWidget);
    expect(find.text('SmartFlow 的记账方式'), findsNothing);
    expect(find.text('开始使用'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty state when no article matches', (tester) async {
    await pumpManualPage(tester);

    await tester.enterText(find.byType(TextField), '不存在的关键词');
    await tester.pump();

    expect(find.text('没有找到相关内容'), findsOneWidget);
    expect(find.text('可以换一个关键词试试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an article navigates to the article page', (
    tester,
  ) async {
    await pumpManualPage(tester);

    await tester.tap(find.text('SmartFlow 的记账方式'));
    await tester.pumpAndSettle();

    expect(find.text('手册文章不存在'), findsNothing);
    expect(find.byTooltip('文章目录'), findsOneWidget);
    expect(find.byTooltip('本页目录'), findsOneWidget);
    expect(find.text('先理解账户、分类和交易之间的关系，再开始记录财务事实。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _manualRouter() {
  return GoRouter(
    initialLocation: '/profile/manual',
    routes: [
      GoRoute(path: '/profile/manual', builder: (_, _) => const ManualPage()),
      GoRoute(
        path: '/profile/manual/:slug',
        builder: (_, state) =>
            ManualArticlePage(slug: state.pathParameters['slug']!),
      ),
    ],
  );
}
