import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app_database.dart';

void main() {
  group('AppDatabase', () {
    test('opens an in-memory database for tests', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      expect(database.schemaVersion, 8);

      final row = await database.customSelect('select 1 as value').getSingle();
      expect(row.read<int>('value'), 1);
    });
  });
}
