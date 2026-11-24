import 'package:smartflow/domain/ledger/entity/book.dart';
import 'package:smartflow/domain/ledger/port/book_repository.dart';

class FakeBookRepository implements BookRepository {
  FakeBookRepository()
    : books = {Book.dailyId: Book(id: Book.dailyId, name: Book.dailyName)};
  final Map<String, Book> books;

  @override
  Future<List<Book>> findAll() async => books.values.toList();
  @override
  Stream<List<Book>> watchAll() => Stream.value(books.values.toList());
  @override
  Future<Book?> findById(String id) async => books[id];
  @override
  Future<bool> hasTransactions(String id) async => false;
  @override
  Future<void> save(Book book) async => books[book.id] = book;
  @override
  Future<void> delete(String id) async => books.remove(id);
}
