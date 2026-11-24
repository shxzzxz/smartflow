import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/entity/book.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v67.dart' as v67;

void main() {
  test(
    'v67 to v68 gives existing parent and child transactions the daily book',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      await verifier.testWithDataIntegrity<v67.DatabaseAtV67, AppDatabase>(
        createOld: v67.DatabaseAtV67.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        oldVersion: 67,
        newVersion: 68,
        createItems: (batch, db) {
          batch.customStatement(
            'INSERT INTO transactions (id, business_purpose, occurred_at, posted_at, '
            'primary_amount_minor, source_kind, parent_transaction_id) '
            "VALUES ('expense', 'dailyExpense', 1768003200, 1768003200, 10000, 'manual', NULL), "
            "('refund', 'refund', 1768089600, 1768089600, 2000, 'manual', 'expense')",
          );
        },
        validateItems: (db) async {
          final transactions = await db.select(db.transactions).get();
          expect(
            transactions.map((row) => row.bookId),
            everyElement(Book.dailyId),
          );
          expect(transactions.map((row) => row.primaryAmountMinor).toSet(), {
            10000,
            2000,
          });
          final books = await db.select(db.books).get();
          expect(books.single.id, Book.dailyId);
          expect(books.single.name, Book.dailyName);
          final constraints = await db
              .customSelect('PRAGMA foreign_key_list(transactions)')
              .get();
          expect(constraints, isEmpty);
        },
      );
    },
  );
}
