import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/manual_article_page.dart';

import 'manual_test_assets.dart';

void main() {
  setUp(mockManualAssets);
  tearDown(clearManualAssetsMock);

  Future<void> pumpArticle(WidgetTester tester, String slug) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _manualRouter(slug),
      ),
    );
    // 等待文章内容加载完成（加载指示器消失），避免对无限动画做 pumpAndSettle。
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets('renders intro, markdown features and related articles', (
    tester,
  ) async {
    await pumpArticle(tester, 'getting-started');

    expect(find.byTooltip('文章目录'), findsOneWidget);
    expect(find.byTooltip('本页目录'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('SmartFlow 的记账方式'), findsWidgets);
    expect(find.text('先理解账户、分类和交易之间的关系，再开始记录财务事实。'), findsOneWidget);
    expect(find.text('先理解三个概念'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(4));
    expect(
      find.text('账户决定余额变化，分类决定收支统计。分类不是余额账户，转账也不会被统计为收入或支出。'),
      findsOneWidget,
    );
    expect(find.text('相关文章'), findsOneWidget);
    expect(find.text('如何记录一笔支出'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders tables and nested headings', (tester) async {
    await pumpArticle(tester, 'ledger-concepts');

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('账户'), findsWidgets);
    expect(find.text('为什么余额和收支不是一回事'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory button opens article list and navigates', (
    tester,
  ) async {
    await pumpArticle(tester, 'getting-started');

    await tester.tap(find.byTooltip('文章目录'));
    await tester.pumpAndSettle();

    expect(find.text('文章目录'), findsOneWidget);
    expect(find.text('计息方式和关键指标'), findsOneWidget);
    expect(find.text('SmartFlow 的记账方式'), findsNWidgets(3));

    await tester.tap(find.text('计息方式和关键指标').last);
    await tester.pumpAndSettle();

    expect(find.text('文章目录'), findsNothing);
    expect(find.text('计息方式和关键指标'), findsWidgets);
    expect(find.text('计息方式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows not found state for an unknown slug', (tester) async {
    await pumpArticle(tester, 'not-a-real-slug');

    expect(find.text('手册文章不存在'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _manualRouter(String slug) {
  return GoRouter(
    initialLocation: '/profile/manual/$slug',
    routes: [
      GoRoute(
        path: '/profile/manual/:slug',
        builder:
            (_, state) =>
                ManualArticlePage(slug: state.pathParameters['slug']!),
      ),
    ],
  );
}
