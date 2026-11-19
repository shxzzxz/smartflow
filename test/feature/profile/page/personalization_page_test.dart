import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/app_shell.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_appearance_theme.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/personalization_page.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    _SettingsStore store, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
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
                      builder: (context) => const PersonalizationPage(),
                    ),
                  ),
                  child: const Text('打开个性化设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开个性化设置'));
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

  testWidgets('theme, gradient and button edits preview without saving', (
    tester,
  ) async {
    final store = _SettingsStore();
    await open(tester, store);
    final globalTheme = Theme.of(
      tester.element(find.byType(PersonalizationPage)),
    );
    expect(find.text('#1677FF'), findsNWidgets(2));

    await chooseColor(tester, '主题色', 'E7AE47');
    final previewContext = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey('personalization-preview')),
        matching: find.byType(AppBottomNavigationBar),
      ),
    );
    expect(
      Theme.of(previewContext).colorScheme.primary,
      const Color(0xFFE7AE47),
    );
    expect(
      Theme.of(previewContext).extension<AppAppearanceTheme>()!.gradientColor,
      const Color(0xFF1677FF),
    );
    await chooseColor(tester, '背景基色', 'B73831');
    expect(
      Theme.of(previewContext).colorScheme.primary,
      const Color(0xFFE7AE47),
    );
    expect(
      Theme.of(previewContext).extension<AppAppearanceTheme>()!.gradientColor,
      const Color(0xFFB73831),
    );
    expect(
      Theme.of(tester.element(find.byType(PersonalizationPage))).colorScheme,
      globalTheme.colorScheme,
    );
    expect(store.writes, 0);

    await tester.tap(find.text('布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记账悬浮按钮'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(store.settings.showAddTransactionFab, isTrue);

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
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
    expect(store.settings.showAddTransactionFab, isFalse);
    expect(find.text('未保存'), findsNothing);
    expect(find.text('个性化设置已保存'), findsOneWidget);
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
      expect(find.byType(PersonalizationPage), findsNothing);
      expect(store.writes, 0);
      expect(store.settings.appearance, const AppAppearanceSettings());

      await tester.tap(find.text('打开个性化设置'));
      await tester.pumpAndSettle();
      expect(find.text('#1677FF'), findsNWidgets(2));
      expect(find.text('未保存'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background styles preview and preserve sliders until saved', (
    tester,
  ) async {
    final store = _SettingsStore();
    await open(tester, store);
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    final previewContext = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey('personalization-preview')),
        matching: find.byType(AppBottomNavigationBar),
      ),
    );
    final savedBackground = Theme.of(
      tester.element(find.byType(PersonalizationPage)),
    ).extension<AppAppearanceTheme>()!;
    await tester.tap(find.text('纯色'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(
      Theme.of(previewContext).extension<AppAppearanceTheme>()!.backgroundStyle,
      AppBackgroundStyle.solid,
    );
    expect(store.writes, 0);
    expect(
      store.settings.appearance.backgroundStyle,
      AppBackgroundStyle.multiGlow,
    );
    expect(
      Theme.of(
        tester.element(find.byType(PersonalizationPage)),
      ).extension<AppAppearanceTheme>()!,
      savedBackground,
    );

    await tester.tap(find.text('单色光晕'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    final selected = Theme.of(previewContext).extension<AppAppearanceTheme>()!;
    expect(selected.backgroundStyle, AppBackgroundStyle.singleGlow);
    expect(selected.gradientDepth, 0.35);
    expect(selected.gradientRange, 0.65);

    await tester.tap(find.text('纯色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(store.settings.appearance.backgroundStyle, AppBackgroundStyle.solid);
    expect(store.settings.appearance.gradientDepth, 0.35);
    expect(store.settings.appearance.gradientRange, 0.65);
    expect(find.text('未保存'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.4]) {
      testWidgets(
        'all panels fit a narrow $brightness screen at scale $scale',
        (tester) async {
          await open(
            tester,
            _SettingsStore(),
            brightness: brightness,
            textScale: scale,
          );
          expect(find.text('主题色'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final editor = find.byKey(const ValueKey('personalization-editor'));
          final height = tester.getSize(editor).height;
          for (final label in ['布局', '外观', '颜色']) {
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(tester.getSize(editor).height, height);
            expect(tester.takeException(), isNull);
          }
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
