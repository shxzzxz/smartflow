import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test('fresh databases create the current v51 schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();

    expect(version.read<int>('user_version'), 51);
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'advance_cases'",
          )
          .get(),
      isNotEmpty,
    );

    final accountColumns = await db
        .customSelect('PRAGMA table_info(accounts)')
        .get();
    final columnNames = accountColumns
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(columnNames, isNot(contains('credit_limit_minor')));
    expect(columnNames, isNot(contains('billing_day')));
    expect(columnNames, isNot(contains('repayment_day')));
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' "
            "AND name = 'installment_refund_reductions'",
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
