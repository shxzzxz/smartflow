import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/infrastructure/database/drift_app_settings_store.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftAppSettingsStore', () {
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
