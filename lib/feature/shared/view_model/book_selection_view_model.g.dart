// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_selection_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookList)
final bookListProvider = BookListProvider._();

final class BookListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Book>>,
          List<Book>,
          Stream<List<Book>>
        >
    with $FutureModifier<List<Book>>, $StreamProvider<List<Book>> {
  BookListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookListHash();

  @$internal
  @override
  $StreamProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Book>> create(Ref ref) {
    return bookList(ref);
  }
}

String _$bookListHash() => r'7acbc974bb1e1160bf00c8d6c8cc37d04f1aaf01';

@ProviderFor(BookSelectionViewModel)
final bookSelectionViewModelProvider = BookSelectionViewModelProvider._();

final class BookSelectionViewModelProvider
    extends
        $NotifierProvider<
          BookSelectionViewModel,
          AsyncValue<BookSelectionState>
        > {
  BookSelectionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSelectionViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSelectionViewModelHash();

  @$internal
  @override
  BookSelectionViewModel create() => BookSelectionViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<BookSelectionState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<BookSelectionState>>(
        value,
      ),
    );
  }
}

String _$bookSelectionViewModelHash() =>
    r'bdda8fb85c1213d896d6a7b73ef7a4002191b0da';

abstract class _$BookSelectionViewModel
    extends $Notifier<AsyncValue<BookSelectionState>> {
  AsyncValue<BookSelectionState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<BookSelectionState>,
              AsyncValue<BookSelectionState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BookSelectionState>,
                AsyncValue<BookSelectionState>
              >,
              AsyncValue<BookSelectionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
