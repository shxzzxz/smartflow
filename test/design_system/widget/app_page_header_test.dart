import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/header.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_popup_menu_button.dart';

void main() {
  Widget wrap(Widget header) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: header),
    );
  }

  testWidgets('page header hides the back button on a root route', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppPageHeader(title: '资产')));

    expect(find.byTooltip('返回'), findsNothing);
    expect(find.text('资产'), findsOneWidget);
  });

  testWidgets('page header shows the back button on a pushed route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const Scaffold(
                                body: AppPageHeader(title: '账户概览'),
                              ),
                        ),
                      ),
                  child: const Text('打开'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('返回'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('账户概览'), findsNothing);
  });

  testWidgets('page header suppresses the back button when asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const Scaffold(
                                body: AppPageHeader(
                                  title: '账户概览',
                                  showBackButton: false,
                                ),
                              ),
                        ),
                      ),
                  child: const Text('打开'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回'), findsNothing);
  });

  testWidgets('page header routes the back action to onBack', (tester) async {
    var backPressed = 0;
    await tester.pumpWidget(
      wrap(AppPageHeader(title: '数据导入', onBack: () => backPressed += 1)),
    );

    await tester.tap(find.byTooltip('返回'));

    expect(backPressed, 1);
  });

  testWidgets('page header renders the subtitle below the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const AppPageHeader(title: '餐饮', subtitle: '二级分类构成')),
    );

    expect(
      tester.getTopLeft(find.text('二级分类构成')).dy,
      greaterThan(tester.getTopLeft(find.text('餐饮')).dy),
    );
    expect(
      tester.getTopLeft(find.text('二级分类构成')).dx,
      tester.getTopLeft(find.text('餐饮')).dx,
    );
  });

  testWidgets('page header keeps a long title on one line', (tester) async {
    const longTitle = '这是一个非常长的页面标题用来验证溢出行为不会换行也不会溢出布局';
    await tester.pumpWidget(wrap(const AppPageHeader(title: longTitle)));

    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page header normalises action button geometry', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppPageHeader(
          title: '资产',
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.add_line,
              tooltip: '新建账户',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(RemixIcons.eye_line),
              tooltip: '隐藏余额',
              iconSize: 30,
              onPressed: () {},
            ),
            const AppPopupMenuButton(
              tooltip: '更多操作',
              icon: RemixIcons.more_2_fill,
              items: [],
            ),
          ],
        ),
      ),
    );

    const expected = Size.square(AppHeaderTokens.iconButtonSize);
    expect(tester.getSize(find.byTooltip('新建账户')), expected);
    expect(tester.getSize(find.byTooltip('隐藏余额')), expected);
    expect(tester.getSize(find.byTooltip('更多操作')), expected);
  });

  testWidgets('page header aligns edge glyphs to the content inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppPageHeader(
          title: '账户概览',
          onBack: () {},
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.add_line,
              tooltip: '新建账户',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final width = tester.getSize(find.byType(AppPageHeader)).width;
    expect(
      tester.getTopLeft(find.byIcon(RemixIcons.arrow_left_s_line)).dx,
      moreOrLessEquals(AppHeaderTokens.edgeInset),
    );
    expect(
      width - tester.getBottomRight(find.byIcon(RemixIcons.add_line)).dx,
      moreOrLessEquals(AppHeaderTokens.edgeInset),
    );
  });

  testWidgets('page header hosts a custom title control', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppPageHeader.custom(
          titleContent: Text('2026年5月'),
          showBackButton: false,
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('2026年5月')).dx,
      moreOrLessEquals(AppHeaderTokens.edgeInset),
    );
  });
}
