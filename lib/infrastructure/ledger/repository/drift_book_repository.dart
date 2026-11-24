import 'package:drift/drift.dart';

import '../../../domain/ledger/entity/book.dart';
import '../../../domain/ledger/port/book_repository.dart';
import '../../database/app_database.dart';

class DriftBookRepository implements BookRepository {
  const DriftBookRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$BooksTable, BookRow> _query() =>
      _db.select(_db.books)..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);

  Book _map(BookRow row) =>
      Book(id: row.id, name: row.name, sortOrder: row.sortOrder);

  @override
  Future<List<Book>> findAll() async =>
      (await _query().get()).map(_map).toList();

  @override
  Stream<List<Book>> watchAll() =>
      _query().watch().map((rows) => rows.map(_map).toList());

  @override
  Future<Book?> findById(String id) async {
    final row = await (_db.select(
      _db.books,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<bool> hasTransactions(String id) async =>
      (await (_db.selectOnly(_db.transactions)
                ..addColumns([_db.transactions.id])
                ..where(_db.transactions.bookId.equals(id))
                ..limit(1))
              .get())
          .isNotEmpty;

  @override
  Future<void> save(Book book) async {
    final values = BooksCompanion(
      name: Value(book.name),
      sortOrder: Value(book.sortOrder),
      updatedAt: Value(DateTime.now()),
    );
    final changed = await (_db.update(
      _db.books,
    )..where((table) => table.id.equals(book.id))).write(values);
    if (changed == 0) {
      await _db.into(_db.books).insert(values.copyWith(id: Value(book.id)));
    }
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.books)..where((table) => table.id.equals(id))).go();
}
