import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_appearance_theme.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_scaffold.dart';
import 'package:smartflow/feature/profile/page/theme_appearance_page.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    _SettingsStore store, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    double screenWidth = 320,
  }) async {
    tester.view.physicalSize = Size(screenWidth, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(appearance: store.settings.appearance)
        : AppTheme.light(appearance: store.settings.appearance);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const ThemeAppearancePage(),
                    ),
                  ),
                  child: const Text('打开主题外观'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开主题外观'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseColor(
    WidgetTester tester,
    String label,
    String hex,
  ) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), hex);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('完成'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  }

  testWidgets('theme and background edits stay local until saved', (
    tester,
  ) async {
    final store = _SettingsStore();
    await open(tester, store);
    final globalTheme = Theme.of(
      tester.element(find.byType(ThemeAppearancePage)),
    );
    expect(find.text('#1677FF'), findsNWidgets(2));

    await chooseColor(tester, '主题色', 'E7AE47');
    final pageContext = tester.element(find.byType(AppScaffold));
    expect(Theme.of(pageContext).colorScheme.primary, const Color(0xFFE7AE47));
    expect(
      Theme.of(pageContext).extension<AppAppearanceTheme>()!.gradientColor,
      const Color(0xFF1677FF),
    );
    await chooseColor(tester, '背景基色', 'B73831');
    expect(Theme.of(pageContext).colorScheme.primary, const Color(0xFFE7AE47));
    expect(
      Theme.of(pageContext).extension<AppAppearanceTheme>()!.gradientColor,
      const Color(0xFFB73831),
    );
    expect(
      Theme.of(tester.element(find.byType(ThemeAppearancePage))).colorScheme,
      globalTheme.colorScheme,
    );
    expect(store.writes, 0);

    await tester.ensureVisible(find.byType(Slider).first);
    await tester.drag(find.byType(Slider).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
    expect(store.writes, 0);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(store.settings.appearance.primaryColor, 0xFFE7AE47);
    expect(store.settings.appearance.backgroundSeedColor, 0xFFB73831);
    expect(store.settings.appearance.gradientDepth, 0);
    expect(find.text('未保存'), findsNothing);
    expect(find.text('主题外观已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discarding an unsaved theme leaves stored preferences unchanged',
    (tester) async {
      final store = _SettingsStore();
      await open(tester, store);
      await chooseColor(tester, '主题色', 'E7AE47');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.text('#E7AE47'), findsOneWidget);
      expect(store.writes, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemeAppearancePage), findsNothing);
      expect(store.writes, 0);
      expect(store.settings.appearance, const AppAppearanceSettings());

      await tester.tap(find.text('打开主题外观'));
      await tester.pumpAndSettle();
      expect(find.text('#1677FF'), findsNWidgets(2));
      expect(find.text('未保存'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background styles apply locally and preserve sliders until saved',
    (tester) async {
      final store = _SettingsStore();
      await open(tester, store, screenWidth: 360);
      final pageContext = tester.element(find.byType(AppScaffold));
      final savedBackground = Theme.of(
        tester.element(find.byType(ThemeAppearancePage)),
      ).extension<AppAppearanceTheme>()!;
      await tester.ensureVisible(find.text('纯色'));
      final labelLeft = tester.getTopLeft(find.text('背景风格')).dx;
      final optionLeft = tester.getTopLeft(find.text('纯色')).dx;
      await tester.tap(find.text('纯色'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(
        tester.getTopLeft(find.text('背景风格')).dx,
        closeTo(labelLeft, 0.01),
        reason: '切换为纯色后，背景风格的左边距应保持一致。',
      );
      expect(
        tester.getTopLeft(find.text('纯色')).dx,
        closeTo(optionLeft, 0.01),
        reason: '隐藏滑杆不应使背景风格选项横向偏移。',
      );
      expect(
        Theme.of(pageContext).extension<AppAppearanceTheme>()!.backgroundStyle,
        AppBackgroundStyle.solid,
      );
      expect(store.writes, 0);
      expect(
        store.settings.appearance.backgroundStyle,
        AppBackgroundStyle.multiGlow,
      );
      expect(
        Theme.of(
          tester.element(find.byType(ThemeAppearancePage)),
        ).extension<AppAppearanceTheme>()!,
        savedBackground,
      );

      await tester.tap(find.text('单色光晕'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(2));
      expect(tester.getTopLeft(find.text('背景风格')).dx, closeTo(labelLeft, 0.01));
      final selected = Theme.of(pageContext).extension<AppAppearanceTheme>()!;
      expect(selected.backgroundStyle, AppBackgroundStyle.singleGlow);
      expect(selected.gradientDepth, 0.35);
      expect(selected.gradientRange, 0.65);

      await tester.tap(find.text('纯色'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(
        store.settings.appearance.backgroundStyle,
        AppBackgroundStyle.solid,
      );
      expect(store.settings.appearance.gradientDepth, 0.35);
      expect(store.settings.appearance.gradientRange, 0.65);
      expect(find.text('未保存'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets(
        'all settings are reachable on a narrow $brightness screen at scale $scale',
        (tester) async {
          await open(
            tester,
            _SettingsStore(),
            brightness: brightness,
            textScale: scale,
          );
          expect(find.text('主题色'), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final label in ['主题色', '背景基色', '背景风格', '渐变深浅', '渐变范围']) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            expect(find.text(label).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
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
