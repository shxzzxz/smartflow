import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/infrastructure/database/drift_app_settings_store.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftAppSettingsStore', () {
    test(
      'persists independent icon styles and preserves them when another setting changes',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);
        expect((await store.read()).accountIconStyle, isEmpty);
        await store.save(
          const AppSettings(
            accountIconStyle: 'color-shape',
            categoryIconStyle: 'soft-duotone',
          ),
        );
        final loaded = await store.read();
        await store.save(loaded.copyWith(showBottomNavLabels: false));
        final restored = await store.read();
        expect(restored.accountIconStyle, 'color-shape');
        expect(restored.categoryIconStyle, 'soft-duotone');
        expect(restored.showBottomNavLabels, isFalse);
      },
    );
    test(
      'read returns the standard pull-to-create sensitivity by default',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);

        final settings = await store.read();

        expect(
          settings.pullToCreateSensitivity,
          PullToCreateSensitivity.standard,
        );
        expect(settings.copyPreviousMonthBudgetsOnOpen, isFalse);
        expect(settings.cashflowPeriodMetric, CashflowPeriodMetric.periodDelta);
      },
    );

    test('save then read round-trips pull-to-create sensitivity', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftAppSettingsStore(database);

      await store.save(
        const AppSettings(
          pullToCreateSensitivity: PullToCreateSensitivity.sensitive,
        ),
      );

      final settings = await store.read();
      expect(
        settings.pullToCreateSensitivity,
        PullToCreateSensitivity.sensitive,
      );
    });

    test('save then read round-trips copy previous month budgets', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftAppSettingsStore(database);

      await store.save(const AppSettings(copyPreviousMonthBudgetsOnOpen: true));

      final settings = await store.read();
      expect(settings.copyPreviousMonthBudgetsOnOpen, isTrue);
    });

    test('save then read round-trips cashflow period metric', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftAppSettingsStore(database);

      await store.save(
        const AppSettings(
          cashflowPeriodMetric: CashflowPeriodMetric.previousMonthRatio,
        ),
      );

      final settings = await store.read();
      expect(
        settings.cashflowPeriodMetric,
        CashflowPeriodMetric.previousMonthRatio,
      );
    });
  });
}
