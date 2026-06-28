import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test('schema v14 creates credit repayment tables', () async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: _createV13Database),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);

    await database
        .into(database.repayments)
        .insert(
          RepaymentsCompanion.insert(
            id: 'repayment-1',
            repaymentType: 'BILL',
            targetType: 'BILL',
            targetId: 'bill-1',
          ),
        );
    await database
        .into(database.repaymentItems)
        .insert(
          RepaymentItemsCompanion.insert(
            id: 'item-1',
            repaymentId: 'repayment-1',
            billItemId: const Value('bill-item-1'),
            allocatedPrincipalMinor: 1000,
            allocatedInterestMinor: 0,
            allocatedFeeMinor: 0,
            allocatedDiscountMinor: 0,
          ),
        );

    expect(await database.select(database.repayments).get(), hasLength(1));
    expect(await database.select(database.repaymentItems).get(), hasLength(1));
  });
}

void _createV13Database(dynamic database) {
  database.execute('''
    CREATE TABLE app_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO app_metadata (key, value, updated_at) "
    "VALUES ('builtin_data_version', '8', 0)",
  );
  database.execute('PRAGMA user_version = 13');
}
