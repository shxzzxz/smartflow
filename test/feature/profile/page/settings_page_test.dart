import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/settings_page.dart';

void main() {
  testWidgets('user can select pull-to-create sensitivity', (tester) async {
    final store = _InMemoryAppSettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('下拉新增交易'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('灵敏').last);
    await tester.pumpAndSettle();

    expect(
      (await store.read()).pullToCreateSensitivity,
      PullToCreateSensitivity.sensitive,
    );
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
