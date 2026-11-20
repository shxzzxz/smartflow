import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_chrome_theme.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/feature/profile/page/header_appearance_page.dart';
import 'package:smartflow/feature/profile/page/navigation_appearance_page.dart';
import 'package:smartflow/feature/profile/widget/chrome_appearance_preview.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    _SettingsStore store, {
    required bool header,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, child) {
            final appearance =
                ref.watch(appSettingsViewModelProvider).value?.appearance ??
                const AppAppearanceSettings();
            return MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark(appearance: appearance)
                  : AppTheme.light(appearance: appearance),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => header
                            ? const HeaderAppearancePage()
                            : const NavigationAppearancePage(),
                      ),
                    ),
                    child: const Text('打开外观'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开外观'));
    await tester.pumpAndSettle();
  }

  Finder pageScroll(bool header) => find
      .descendant(
        of: find.byKey(
          ValueKey(
            header
                ? 'header-appearance-settings'
                : 'navigation-appearance-settings',
          ),
        ),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets(
    'navigation preview edits are local, interactive and saved together',
    (tester) async {
      final store = _SettingsStore();
      await open(tester, store, header: false);
      await tester.tap(find.text('玻璃'));
      await tester.pumpAndSettle();
      final preview = find.byType(NavigationAppearancePreview);
      await tester.tap(find.descendant(of: preview, matching: find.text('资产')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: preview,
          matching: find.byIcon(RemixIcons.wallet_3_fill),
        ),
        findsOneWidget,
      );
      expect(find.byType(NavigationAppearancePage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(Slider).first,
        150,
        scrollable: pageScroll(false),
      );
      await tester.drag(find.byType(Slider).first, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await tester.scrollUntilVisible(
        preview,
        -200,
        scrollable: pageScroll(false),
      );
      await tester.pumpAndSettle();
      final filter = tester
          .widget<BackdropFilter>(
            find.descendant(of: preview, matching: find.byType(BackdropFilter)),
          )
          .filter;
      expect(
        filter,
        ImageFilter.compose(
          outer: ColorFilter.saturation(
            AppChromeTheme.defaults.navigationGlass.saturation,
          ),
          inner: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        ),
      );
      await tester.ensureVisible(find.text('导航栏文字'));
      await tester.tap(find.text('导航栏文字'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: preview, matching: find.text('首页')),
        findsNothing,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(
        store.settings.bottomNavigationStyle,
        BottomNavigationStyle.frostedGlass,
      );
      expect(store.settings.showBottomNavLabels, isFalse);
      expect(store.settings.appearance.navigationGlass.blurSigma, 40);
      expect(find.text('未保存'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'classic header preview removes glass and retains tabs and geometry',
    (tester) async {
      final store = _SettingsStore();
      await open(tester, store, header: true);
      final preview = find.byType(HeaderAppearancePreview);
      final previewHeader = find.descendant(
        of: preview,
        matching: find.byType(AppPageHeader),
      );
      final size = tester.getSize(previewHeader);
      expect(
        find.descendant(of: preview, matching: find.byType(BackdropFilter)),
        findsNWidgets(4),
      );
      await tester.tap(find.text('经典'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: preview, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(tester.getSize(previewHeader), size);
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: previewHeader,
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.every(
          (decoration) => decoration.boxShadow?.isNotEmpty != true,
        ),
        isTrue,
      );
      await tester.tap(find.descendant(of: preview, matching: find.text('明细')));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.settings.appearance.headerStyle, AppHeaderStyle.classic);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final header in [false, true]) {
    testWidgets(
      '${header ? 'header' : 'navigation'} unsaved exit can continue or discard edits',
      (tester) async {
        final store = _SettingsStore();
        await open(tester, store, header: header);
        await tester.tap(find.text(header ? '经典' : '玻璃'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('继续编辑'));
        await tester.pumpAndSettle();
        expect(find.text('未保存'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('放弃修改'));
        await tester.pumpAndSettle();
        expect(find.text('打开外观'), findsOneWidget);
        expect(store.writes, 0);
        expect(store.settings.appearance, const AppAppearanceSettings());
        expect(
          store.settings.bottomNavigationStyle,
          BottomNavigationStyle.classic,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final brightness in Brightness.values) {
      testWidgets(
        '${header ? 'header' : 'navigation'} settings remain reachable at large text in $brightness',
        (tester) async {
          await open(
            tester,
            _SettingsStore(),
            header: header,
            brightness: brightness,
            textScale: 2,
          );
          if (!header) {
            await tester.scrollUntilVisible(
              find.text('玻璃'),
              100,
              scrollable: pageScroll(false),
            );
            await tester.tap(find.text('玻璃'));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('阴影强度'),
            200,
            scrollable: pageScroll(header),
          );
          await tester.pumpAndSettle();
          expect(find.text('阴影强度').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _SettingsStore implements AppSettingsStore {
  AppSettings settings = const AppSettings();
  int writes = 0;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings value) async {
    settings = value;
    writes++;
  }
}
