import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test('fresh databases start at the v49 contract baseline', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();

    expect(version.read<int>('user_version'), 49);
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'advance_cases'",
          )
          .get(),
      isNotEmpty,
    );
  });

  test('pre-baseline databases are rejected instead of migrated', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-database-contract-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/smartflow.sqlite');

    final baseline = AppDatabase(NativeDatabase(file));
    await baseline.customSelect('SELECT 1').get();
    await baseline.customStatement('PRAGMA user_version = 48');
    await baseline.close();

    final current = AppDatabase(NativeDatabase(file));
    addTearDown(current.close);

    await expectLater(
      current.customSelect('SELECT 1').get(),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('v48 is no longer supported'),
        ),
      ),
    );
  });
}
