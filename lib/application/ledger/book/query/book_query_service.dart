import '../../../../domain/ledger/entity/book.dart';
import '../../../../domain/ledger/port/book_repository.dart';

class BookQueryService {
  const BookQueryService(this._books);
  final BookRepository _books;

  Future<List<Book>> findBooks() => _books.findAll();

  Stream<List<Book>> watchBooks() => _books.watchAll();
  Future<Book?> findBook(String id) => _books.findById(id);
}
