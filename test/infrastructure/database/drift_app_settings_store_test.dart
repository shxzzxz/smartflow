import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_app_settings_store.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftAppSettingsStore', () {
    test(
      'repayment reminders default to 22:00 and persist time and enablement',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);
        final defaults = await store.read();
        expect(
          defaults.repaymentReminderTime,
          const NotificationTime(hour: 22, minute: 0),
        );
        expect(defaults.repaymentRemindersEnabled, isTrue);
        await store.save(
          defaults.copyWith(
            repaymentReminderTime: const NotificationTime(hour: 21, minute: 30),
            repaymentRemindersEnabled: false,
          ),
        );
        final reloaded = await DriftAppSettingsStore(database).read();
        expect(
          reloaded.repaymentReminderTime,
          const NotificationTime(hour: 21, minute: 30),
        );
        expect(reloaded.repaymentRemindersEnabled, isFalse);
        expect(
          reloaded.pullToCreateSensitivity,
          defaults.pullToCreateSensitivity,
        );
        await database
            .into(database.appMetadata)
            .insertOnConflictUpdate(
              AppMetadataCompanion.insert(
                key: 'settings.repayment_reminder_time',
                value: '1440',
              ),
            );
        expect(
          (await store.read()).repaymentReminderTime,
          defaults.repaymentReminderTime,
        );
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
        expect(
          settings.transactionListDisplayMode,
          TransactionListDisplayMode.standard,
        );
        expect(settings.appearance, const AppAppearanceSettings());
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

    test(
      'defaults to classic navigation and round-trips frosted glass',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);

        expect(
          (await store.read()).bottomNavigationStyle,
          BottomNavigationStyle.classic,
        );

        await store.save(
          const AppSettings(
            bottomNavigationStyle: BottomNavigationStyle.frostedGlass,
          ),
        );

        expect(
          (await store.read()).bottomNavigationStyle,
          BottomNavigationStyle.frostedGlass,
        );
      },
    );

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

    test('save then read round-trips transaction list display mode', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftAppSettingsStore(database);

      await store.save(
        const AppSettings(
          transactionListDisplayMode: TransactionListDisplayMode.compact,
        ),
      );

      final settings = await store.read();
      expect(
        settings.transactionListDisplayMode,
        TransactionListDisplayMode.compact,
      );
    });

    test(
      'persists the complete appearance and button selection together',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);
        const appearance = AppAppearanceSettings(
          primaryColor: 0xFFE7AE47,
          backgroundSeedColor: 0xFF1677FF,
          backgroundStyle: AppBackgroundStyle.singleGlow,
          incomeColor: 0xFF9254DE,
          expenseColor: 0xFF1976D2,
          gradientDepth: 0.8,
          gradientRange: 0.9,
          headerStyle: AppHeaderStyle.classic,
          navigationGlass: AppGlassSettings(
            blurSigma: 12,
            backgroundOpacity: 0.4,
            saturation: 1.6,
            shadowOpacity: 0.2,
          ),
          headerBackgroundGlass: AppGlassSettings(
            blurSigma: 24,
            backgroundOpacity: 0.5,
            saturation: 1,
            shadowOpacity: 0,
          ),
          headerControlGlass: AppGlassSettings(
            blurSigma: 6,
            backgroundOpacity: 0.2,
            saturation: 1.3,
            shadowOpacity: 0.05,
          ),
        );

        await store.save(
          const AppSettings(
            appearance: appearance,
            showAddTransactionFab: false,
            showBottomNavLabels: false,
          ),
        );
        final reloaded = await DriftAppSettingsStore(database).read();
        expect(reloaded.appearance, appearance);
        expect(reloaded.showAddTransactionFab, isFalse);
        expect(reloaded.showBottomNavLabels, isFalse);
        for (final style in AppBackgroundStyle.values) {
          final selected = appearance.copyWith(backgroundStyle: style);
          await store.save(AppSettings(appearance: selected));
          expect((await store.read()).appearance, selected);
        }
      },
    );

    test('malformed and out-of-range appearance data loads safely', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftAppSettingsStore(database);
      Future<void> writeAppearance(String value) async {
        await database
            .into(database.appMetadata)
            .insertOnConflictUpdate(
              AppMetadataCompanion.insert(
                key: 'settings.appearance',
                value: value,
                updatedAt: Value(DateTime.utc(2026, 11, 19)),
              ),
            );
      }

      await writeAppearance('broken-json');
      expect((await store.read()).appearance, const AppAppearanceSettings());
      await writeAppearance('[]');
      expect((await store.read()).appearance, const AppAppearanceSettings());
      await writeAppearance(
        '{"primaryColor":12,"backgroundSeedColor":"bad","backgroundStyle":123,"incomeColor":4287780062,"gradientDepth":2,"gradientRange":-2}',
      );
      final sanitized = (await store.read()).appearance;
      expect(sanitized.primaryColor, AppAppearanceSettings.useDefaultColor);
      expect(
        sanitized.backgroundSeedColor,
        AppAppearanceSettings.useDefaultColor,
      );
      expect(sanitized.backgroundStyle, AppBackgroundStyle.multiGlow);
      expect(sanitized.incomeColor, 0xFF9254DE);
      expect(sanitized.gradientDepth, 1);
      expect(sanitized.gradientRange, 0);
      await writeAppearance(
        '{"headerStyle":42,"navigationGlass":[],"headerBackgroundGlass":{"blurSigma":-10,"backgroundOpacity":2},"headerControlGlass":{"blurSigma":"bad","saturation":99,"shadowOpacity":-1}}',
      );
      final chrome = (await store.read()).appearance;
      expect(chrome.headerStyle, AppHeaderStyle.frostedGlass);
      expect(chrome.navigationGlass, const AppGlassSettings());
      expect(chrome.headerBackgroundGlass.blurSigma, 0);
      expect(chrome.headerBackgroundGlass.backgroundOpacity, 1);
      expect(chrome.headerControlGlass.blurSigma, AppGlassSettings.useDefault);
      expect(chrome.headerControlGlass.saturation, 99);
    });

    test(
      'legacy appearance adopts its theme color as an independent background',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final store = DriftAppSettingsStore(database);
        await database
            .into(database.appMetadata)
            .insert(
              AppMetadataCompanion.insert(
                key: 'settings.appearance',
                value: '{"primaryColor":4294945088,"gradientDepth":0.7}',
                updatedAt: Value(DateTime.utc(2026, 11, 19)),
              ),
            );
        final loaded = await store.read();
        expect(loaded.appearance.primaryColor, 0xFFFFA940);
        expect(loaded.appearance.backgroundSeedColor, 0xFFFFA940);
        expect(loaded.appearance.backgroundStyle, AppBackgroundStyle.multiGlow);
        await store.save(
          loaded.copyWith(
            appearance: loaded.appearance.copyWith(primaryColor: 0xFF1677FF),
          ),
        );
        final reloaded = await store.read();
        expect(reloaded.appearance.primaryColor, 0xFF1677FF);
        expect(reloaded.appearance.backgroundSeedColor, 0xFFFFA940);
        expect(reloaded.appearance.gradientDepth, 0.7);
      },
    );
  });
}
