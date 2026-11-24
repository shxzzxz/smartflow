import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/ledger/entity/book.dart';
import '../../../../domain/ledger/port/book_repository.dart';
import '../../../../domain/ledger/port/transaction_repository.dart';
import '../../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'book_command.dart';

class BookAppService {
  const BookAppService({
    required BookRepository books,
    required TransactionRepository transactions,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _books = books,
       _transactions = transactions,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final BookRepository _books;
  final TransactionRepository _transactions;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;

  Future<Book> createBook(CreateBookCommand command) => _runner.run(() async {
    final books = await _books.findAll();
    final book = Book(
      id: _idGenerator.newId(),
      name: command.name,
      sortOrder:
          books.fold(
            0,
            (order, book) => book.sortOrder > order ? book.sortOrder : order,
          ) +
          1,
    );
    _assertUniqueName(books, book);
    await _books.save(book);
    return book;
  });

  Future<void> renameBook(RenameBookCommand command) => _runner.run(() async {
    final book = await _requireBook(command.id);
    book.rename(command.name);
    _assertUniqueName(await _books.findAll(), book);
    await _books.save(book);
  });

  Future<void> deleteBook(DeleteBookCommand command) => _runner.run(() async {
    final book = await _requireBook(command.id);
    book.assertCanDelete(
      hasTransactions: await _books.hasTransactions(book.id),
    );
    await _books.delete(book.id);
  });

  Future<void> changeTransactionBook(ChangeTransactionBookCommand command) =>
      _runner.run(() async {
        await _requireBook(command.bookId);
        final transaction = await _transactions.findById(command.transactionId);
        if (transaction == null) {
          throw BusinessException(LedgerErrorCode.transactionNotFound);
        }
        transaction.bookId = command.bookId;
        await _transactions.updateAll([transaction]);
      });

  Future<Book> _requireBook(String id) async {
    final book = await _books.findById(id);
    if (book == null) throw BusinessException(LedgerErrorCode.bookNotFound);
    return book;
  }

  void _assertUniqueName(List<Book> books, Book candidate) {
    if (books.any(
      (book) => book.id != candidate.id && book.name == candidate.name,
    )) {
      throw BusinessException(LedgerErrorCode.bookNameExists);
    }
  }
}
