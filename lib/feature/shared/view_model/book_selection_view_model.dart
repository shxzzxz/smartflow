import '../../../application/shared/app_settings_store.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import 'app_settings_view_model.dart';
import 'action_guard.dart';
import 'ui_action_outcome.dart';

part 'book_selection_view_model.g.dart';

final _logger = Logger('feature.book');

@Riverpod(keepAlive: true)
Stream<List<Book>> bookList(Ref ref) =>
    ref.watch(bookQueryServiceProvider).watchBooks();

class BookSelectionState {
  BookSelectionState({
    required List<Book> books,
    required this.currentBook,
    this.submitting = false,
  }) : books = List.unmodifiable(books);

  final List<Book> books;
  final Book currentBook;
  final bool submitting;

  BookSelectionState withSubmitting(bool value) => BookSelectionState(
    books: books,
    currentBook: currentBook,
    submitting: value,
  );
}

@Riverpod(keepAlive: true)
class BookSelectionViewModel extends _$BookSelectionViewModel {
  bool _submitting = false;
  @override
  AsyncValue<BookSelectionState> build() {
    final settings = ref.watch(appSettingsViewModelProvider);
    final books = ref.watch(bookListProvider);
    if (settings.hasError) {
      return AsyncError(settings.error!, settings.stackTrace!);
    }
    if (books.hasError) {
      return AsyncError(books.error!, books.stackTrace!);
    }
    if (settings.isLoading ||
        books.isLoading ||
        !settings.hasValue ||
        !books.hasValue) {
      return const AsyncLoading();
    }
    return AsyncData(_selection(settings.requireValue, books.requireValue));
  }

  void retry() {
    final settingsFailed = ref.read(appSettingsViewModelProvider).hasError;
    final booksFailed = ref.read(bookListProvider).hasError;
    if (settingsFailed) {
      ref.invalidate(appSettingsViewModelProvider, asReload: true);
    }
    if (booksFailed) ref.invalidate(bookListProvider, asReload: true);
  }

  Future<BookSelectionState> snapshot() async {
    final loaded = state;
    if (loaded.hasValue && !loaded.isLoading && !loaded.hasError) {
      return loaded.requireValue;
    }
    final settingsState = ref.read(appSettingsViewModelProvider);
    final settings = settingsState.hasValue && !settingsState.isLoading
        ? settingsState.requireValue
        : await ref.read(appSettingsViewModelProvider.future);
    final books = await ref.read(bookQueryServiceProvider).findBooks();
    return _selection(settings, books);
  }

  BookSelectionState _selection(AppSettings settings, List<Book> books) {
    final current =
        books.where((book) => book.id == settings.currentBookId).firstOrNull ??
        books.firstWhere((book) => book.isBuiltin);
    return BookSelectionState(
      books: books,
      currentBook: current,
      submitting: _submitting,
    );
  }

  Future<UiActionOutcome<T>> _runManagement<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    _setSubmitting(true);
    try {
      return await guardUiAction(_logger, operation, action);
    } finally {
      if (ref.mounted) _setSubmitting(false);
    }
  }

  void _setSubmitting(bool value) {
    _submitting = value;
    final loaded = state.value;
    if (loaded != null) state = AsyncData(loaded.withSubmitting(value));
  }

  Future<UiActionOutcome<void>> selectBook(String id) =>
      guardUiAction(_logger, 'select book', () async {
        if (await ref.read(bookQueryServiceProvider).findBook(id) == null) {
          throw BusinessException(LedgerErrorCode.bookNotFound);
        }
        await ref
            .read(appSettingsViewModelProvider.notifier)
            .setCurrentBookId(id);
      });

  Future<UiActionOutcome<Book>> createBook(String name) => _runManagement(
    'create book',
    () => ref
        .read(bookAppServiceProvider)
        .createBook(CreateBookCommand(name: name)),
  );

  Future<UiActionOutcome<void>> renameBook(Book book, String name) =>
      _runManagement(
        'rename book',
        () => ref
            .read(bookAppServiceProvider)
            .renameBook(RenameBookCommand(id: book.id, name: name)),
      );

  Future<UiActionOutcome<void>> deleteBook(Book book) =>
      _runManagement('delete book', () async {
        await ref
            .read(bookAppServiceProvider)
            .deleteBook(DeleteBookCommand(id: book.id));
        final settings = await ref.read(appSettingsViewModelProvider.future);
        if (settings.currentBookId == book.id) {
          await ref
              .read(appSettingsViewModelProvider.notifier)
              .setCurrentBookId(Book.dailyId);
        }
      });
}
