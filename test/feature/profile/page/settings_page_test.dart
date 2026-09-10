import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/settings_page.dart';
import 'package:smartflow/widget/business/icon/business_icon_scope.dart';

void main() {
  testWidgets(
    'account and category styles can be selected independently from JSON choices',
    (tester) async {
      final store = _InMemoryAppSettingsStore();
      final catalog = await tester.runAsync(
        () => BusinessIconCatalog.load(rootBundle),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appSettingsStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: BusinessIconScope(
              catalog: catalog!,
              child: const SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('账户图标风格'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('彩色面形'));
      await tester.pumpAndSettle();
      expect((await store.read()).accountIconStyle, 'color-shape');
      expect((await store.read()).categoryIconStyle, isEmpty);
      await tester.tap(find.text('分类图标风格'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('柔和双色'));
      await tester.pumpAndSettle();
      expect((await store.read()).accountIconStyle, 'color-shape');
      expect((await store.read()).categoryIconStyle, 'soft-duotone');
    },
  );
  testWidgets('user can change interface settings from compact rows', (
    tester,
  ) async {
    final store = _InMemoryAppSettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('界面设置'), findsOneWidget);
    expect(find.text('在右下角显示快速记账按钮'), findsNothing);
    expect(find.text('调整首页下拉新增交易的距离灵敏度'), findsNothing);
    expect(find.text('在底部导航图标下方显示文字标签'), findsNothing);
    expect(find.text('下拉灵敏度'), findsOneWidget);
    expect(find.text('下拉新增交易灵敏度'), findsNothing);
    expect(find.byIcon(RemixIcons.arrow_right_s_line), findsOneWidget);
    expect(
      tester.getCenter(find.text('下拉灵敏度')).dx,
      lessThan(tester.getCenter(find.text('标准')).dx),
    );

    await tester.tap(find.text('下拉灵敏度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('灵敏'));
    await tester.pumpAndSettle();

    expect(
      (await store.read()).pullToCreateSensitivity,
      PullToCreateSensitivity.sensitive,
    );

    final beforeToggle = await store.read();
    await tester.tap(find.text('记账悬浮按钮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导航栏文字'));
    await tester.pumpAndSettle();

    final afterToggle = await store.read();
    expect(
      afterToggle.showAddTransactionFab,
      !beforeToggle.showAddTransactionFab,
    );
    expect(afterToggle.showBottomNavLabels, !beforeToggle.showBottomNavLabels);
    expect(
      afterToggle.pullToCreateSensitivity,
      PullToCreateSensitivity.sensitive,
    );
    expect(tester.takeException(), isNull);
  });
}

class _InMemoryAppSettingsStore implements AppSettingsStore {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
