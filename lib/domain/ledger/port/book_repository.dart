import '../entity/book.dart';

abstract interface class BookRepository {
  Future<List<Book>> findAll();
  Stream<List<Book>> watchAll();
  Future<Book?> findById(String id);
  Future<bool> hasTransactions(String id);
  Future<void> save(Book book);
  Future<void> delete(String id);
}
