import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'manual_test_assets.dart';
import 'package:smartflow/feature/profile/page/manual_article_page.dart';

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
    // 等待文章内容加载完成（加载指示器消失）。
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets('toc button opens sheet and jumps to a heading', (tester) async {
    await pumpArticle(tester, 'credit-metrics');

    await tester.tap(find.byTooltip('本页目录'));
    await tester.pumpAndSettle();

    expect(find.text('本页目录'), findsOneWidget);
    expect(find.text('计息方式'), findsNWidgets(2));
    expect(find.text('按月计息'), findsNWidgets(2));

    final before = tester.getRect(find.text('关键指标').last);
    await tester.tap(find.text('关键指标').last);
    await tester.pumpAndSettle();

    expect(find.text('本页目录'), findsNothing);
    final after = tester.getRect(find.text('关键指标').last);
    expect(after.top, lessThan(before.top));
    expect(after.top, greaterThanOrEqualTo(0));
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
