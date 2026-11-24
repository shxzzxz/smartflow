import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/feature/shared/provider/book_providers.dart';

final bookSelectionTestOverride = bookSelectionViewModelProvider.overrideWith(
  _DefaultBookSelectionViewModel.new,
);

final bookListTestOverride = bookListProvider.overrideWith(
  (ref) => Stream.value([Book(id: Book.dailyId, name: Book.dailyName)]),
);

class _DefaultBookSelectionViewModel extends BookSelectionViewModel {
  @override
  AsyncValue<BookSelectionState> build() {
    final book = Book(id: Book.dailyId, name: Book.dailyName);
    return AsyncData(BookSelectionState(books: [book], currentBook: book));
  }
}
