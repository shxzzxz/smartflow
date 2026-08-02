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
  });
}
