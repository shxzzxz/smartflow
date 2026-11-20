import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/shared/app_appearance_settings.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/header.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/design_system/widget/app_frosted_surface.dart';
import 'package:smartflow/design_system/widget/app_month_picker.dart';
import 'package:smartflow/design_system/widget/app_header_tabs.dart';
import 'package:smartflow/design_system/widget/app_scaffold.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';

void main() {
  Widget wrap(Widget header) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: header),
    );
  }

  testWidgets(
    'header glass covers the top safe area while controls stay below it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(240, 180));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final imageKey = GlobalKey();
      var backPressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24),
              viewPadding: const EdgeInsets.only(top: 24),
            ),
            child: child!,
          ),
          home: AppScaffold(
            body: RepaintBoundary(
              key: imageKey,
              child: CustomPaint(
                painter: _StripedHeaderBackdrop(),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      AppPageHeader(title: '账户', onBack: () => backPressed++),
                      const Expanded(child: SizedBox.expand()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(AppPageHeader));
      expect(header.top, 24);
      expect(header.height, AppHeaderTokens.minHeight);
      expect(
        tester.getRect(find.byTooltip('返回')).top,
        greaterThanOrEqualTo(24),
      );
      final contrast = await tester.runAsync(() async {
        final boundary =
            imageKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List();
        int at(int y) {
          var low = 255;
          var high = 0;
          for (var x = 32; x < 80; x++) {
            final red = pixels[(y * image.width + x) * 4];
            if (red < low) low = red;
            if (red > high) high = red;
          }
          return high - low;
        }

        final result = (statusBar: at(8), body: at(header.bottom.toInt() + 16));
        image.dispose();
        return result;
      });
      expect(contrast!.statusBar, lessThan(contrast.body * 0.35));
      await tester.tap(find.byTooltip('返回'));
      expect(backPressed, 1);
    },
  );

  testWidgets('header background blurs wallpaper and keeps it visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RepaintBoundary(
            key: imageKey,
            child: CustomPaint(
              painter: _StripedHeaderBackdrop(),
              child: const Column(
                children: [
                  AppPageHeader(title: '日历', showBackButton: false),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final headerBottom = tester.getRect(find.byType(AppPageHeader)).bottom;
    final samples = await tester.runAsync(() async {
      final boundary =
          imageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = data!.buffer.asUint8List();
      ({int contrast, double mean}) sample(int y) {
        var low = 255;
        var high = 0;
        var total = 0;
        for (var x = 32; x < 80; x++) {
          final red = rgba[(y * image.width + x) * 4];
          total += red;
          if (red < low) low = red;
          if (red > high) high = red;
        }
        return (contrast: high - low, mean: total / 48);
      }

      final result = (
        header: sample(24),
        body: sample(headerBottom.toInt() + 16),
      );
      image.dispose();
      return result;
    });
    expect(samples!.header.contrast, lessThan(samples.body.contrast * 0.35));
    expect(samples.header.mean, greaterThan(samples.body.mean));
    expect(
      samples.header.mean,
      lessThan(samples.body.mean + (255 - samples.body.mean) * 0.85),
    );
  });

  testWidgets(
    'externally supplied header tabs inherit style without changing standalone glass',
    (tester) async {
      var saved = 0;
      final header = DefaultTabController(
        length: 2,
        child: AppPageHeader.custom(
          onBack: () {},
          titleContent: const AppHeaderTabs(labels: ['概览', '明细']),
          actions: [AppHeaderTextButton(label: '保存', onPressed: () => saved++)],
        ),
      );
      Future<void> pump(AppHeaderStyle style) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(
              appearance: AppAppearanceSettings(headerStyle: style),
            ),
            home: Scaffold(
              body: Column(
                children: [
                  header,
                  AppSlidingSegmentedControl<int>(
                    key: const ValueKey('standalone-glass'),
                    variant: AppSegmentedControlVariant.frosted,
                    segments: const [
                      AppSegment(value: 0, label: '周'),
                      AppSegment(value: 1, label: '月'),
                    ],
                    selected: 0,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(AppHeaderStyle.frostedGlass);
      final headerFinder = find.byType(AppPageHeader);
      final headerSize = tester.getSize(headerFinder);
      final tabsSize = tester.getSize(find.byType(AppHeaderTabs));
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(BackdropFilter),
        ),
        findsNWidgets(4),
      );
      await pump(AppHeaderStyle.classic);
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(tester.getSize(headerFinder), headerSize);
      expect(tester.getSize(find.byType(AppHeaderTabs)), tabsSize);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('standalone-glass')),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('明细'));
      await tester.pumpAndSettle();
      expect(
        DefaultTabController.of(
          tester.element(find.byType(AppHeaderTabs)),
        ).index,
        1,
      );
      await tester.tap(find.text('保存'));
      expect(saved, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: AppPageHeader(title: '账户概览')),
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
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: AppPageHeader(title: '账户概览', showBackButton: false),
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
      tester.getCenter(find.text('二级分类构成')).dx,
      tester.getCenter(find.text('餐饮')).dx,
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

  testWidgets('page header supports a text action', (tester) async {
    var confirmed = 0;
    await tester.pumpWidget(
      wrap(
        AppPageHeader(
          title: '导入预览',
          actions: [
            AppHeaderTextButton(label: '确认', onPressed: () => confirmed += 1),
          ],
        ),
      ),
    );

    final button = find.widgetWithText(TextButton, '确认');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, AppHeaderTokens.iconButtonSize);

    await tester.tap(button);
    expect(confirmed, 1);
  });

  testWidgets('page header aligns control surfaces to the content inset', (
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
      tester
          .getTopLeft(
            find.ancestor(
              of: find.byTooltip('返回'),
              matching: find.byType(AppFrostedSurface),
            ),
          )
          .dx,
      moreOrLessEquals(AppHeaderTokens.edgeInset),
    );
    expect(
      width - tester.getBottomRight(find.byType(AppFrostedSurface).last).dx,
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
      tester.getCenter(find.text('2026年5月')).dx,
      tester.getCenter(find.byType(AppPageHeader)).dx,
    );
  });

  testWidgets('keeps the title centered with unequal side widths on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        AppPageHeader(
          title: '账户详情',
          onBack: () {},
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.edit_line,
              tooltip: '编辑',
              onPressed: () {},
            ),
            AppHeaderIconButton(
              icon: RemixIcons.more_2_line,
              tooltip: '更多',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final title = tester.getRect(find.text('账户详情'));
    expect(title.center.dx, moreOrLessEquals(180));
    expect(title.left, greaterThan(tester.getRect(find.byTooltip('返回')).right));
    expect(title.right, lessThan(tester.getRect(find.byTooltip('编辑')).left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom left switch replaces the automatic back control', (
    tester,
  ) async {
    var changed = 0;
    await tester.pumpWidget(
      wrap(
        AppPageHeader(
          title: '日历',
          onBack: () {},
          leading: AppHeaderIconButton(
            icon: RemixIcons.eye_line,
            tooltip: '切换农历',
            selected: true,
            onPressed: () => changed++,
          ),
        ),
      ),
    );
    expect(find.byTooltip('返回'), findsNothing);
    await tester.tap(find.byTooltip('切换农历'));
    expect(changed, 1);
  });

  testWidgets('a wide core control gets its own centered row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const coreKey = ValueKey('wide-core');
    await tester.pumpWidget(
      wrap(
        AppPageHeader.custom(
          onBack: () {},
          titleContent: const SizedBox(key: coreKey, width: 240, height: 36),
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.add_line,
              tooltip: '新建',
              onPressed: () {},
            ),
            AppHeaderTextButton(label: '保存', onPressed: () {}),
          ],
        ),
      ),
    );
    final core = tester.getRect(find.byKey(coreKey));
    expect(core.width, 240);
    expect(core.center.dx, moreOrLessEquals(160));
    expect(core.top, greaterThan(tester.getRect(find.byTooltip('返回')).bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL mirrors the sides and preserves the centered title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        Directionality(
          textDirection: TextDirection.rtl,
          child: AppPageHeader(
            title: '账户',
            onBack: () {},
            actions: [
              AppHeaderIconButton(
                icon: RemixIcons.add_line,
                tooltip: '新建',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getCenter(find.text('账户')).dx, moreOrLessEquals(180));
    expect(
      tester.getRect(find.byTooltip('返回')).left,
      greaterThan(tester.getRect(find.byTooltip('新建')).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('month selector supports picking, arrow taps and swipes', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      wrap(
        AppPageHeader.custom(
          titleContent: AppMonthSelector(
            visibleMonth: DateTime(2018, 9),
            onMonthPressed: () => events.add('pick'),
            onPreviousMonth: () => events.add('previous'),
            onNextMonth: () => events.add('next'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('上个月'));
    await tester.tap(find.byTooltip('下个月'));
    await tester.tap(find.text('2018年09月'));
    await tester.drag(find.byType(AppMonthSelector), const Offset(-120, 0));
    await tester.drag(find.byType(AppMonthSelector), const Offset(120, 0));
    expect(events, ['previous', 'next', 'pick', 'next', 'previous']);
  });

  testWidgets('header tabs stay synchronized with their page views', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DefaultTabController(
          length: 2,
          child: Column(
            children: [
              AppPageHeader.custom(
                titleContent: AppHeaderTabs(labels: ['支出', '收入']),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Center(child: Text('支出内容')),
                    Center(child: Text('收入内容')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text('收入内容'), findsOneWidget);
    await tester.drag(find.byType(TabBarView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('支出内容'), findsOneWidget);
  });
}

class _StripedHeaderBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 4, size.height),
        Paint()..color = (x / 4).toInt().isEven ? Colors.blue : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_StripedHeaderBackdrop oldDelegate) => false;
}
