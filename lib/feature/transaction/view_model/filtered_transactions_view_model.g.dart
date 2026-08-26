// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filtered_transactions_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FilteredTransactionPaging)
final filteredTransactionPagingProvider = FilteredTransactionPagingFamily._();

final class FilteredTransactionPagingProvider
    extends $NotifierProvider<FilteredTransactionPaging, int> {
  FilteredTransactionPagingProvider._({
    required FilteredTransactionPagingFamily super.from,
    required (FilteredTransactionTarget, String) super.argument,
  }) : super(
         retry: null,
         name: r'filteredTransactionPagingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredTransactionPagingHash();

  @override
  String toString() {
    return r'filteredTransactionPagingProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  FilteredTransactionPaging create() => FilteredTransactionPaging();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredTransactionPagingProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredTransactionPagingHash() =>
    r'709efe676a5d9840ad0a135483a7b25b0dab1346';

final class FilteredTransactionPagingFamily extends $Family
    with
        $ClassFamilyOverride<
          FilteredTransactionPaging,
          int,
          int,
          int,
          (FilteredTransactionTarget, String)
        > {
  FilteredTransactionPagingFamily._()
    : super(
        retry: null,
        name: r'filteredTransactionPagingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FilteredTransactionPagingProvider call(
    FilteredTransactionTarget target,
    String targetId,
  ) => FilteredTransactionPagingProvider._(
    argument: (target, targetId),
    from: this,
  );

  @override
  String toString() => r'filteredTransactionPagingProvider';
}

abstract class _$FilteredTransactionPaging extends $Notifier<int> {
  late final _$args = ref.$arg as (FilteredTransactionTarget, String);
  FilteredTransactionTarget get target => _$args.$1;
  String get targetId => _$args.$2;

  int build(FilteredTransactionTarget target, String targetId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

@ProviderFor(filteredTransactions)
final filteredTransactionsProvider = FilteredTransactionsFamily._();

final class FilteredTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  FilteredTransactionsProvider._({
    required FilteredTransactionsFamily super.from,
    required (FilteredTransactionTarget, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'filteredTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredTransactionsHash();

  @override
  String toString() {
    return r'filteredTransactionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<TransactionListReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TransactionListReadModel>> create(Ref ref) {
    final argument = this.argument as (FilteredTransactionTarget, String, int);
    return filteredTransactions(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredTransactionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredTransactionsHash() =>
    r'8715cb98d2ed05c2dc088c5c15cc1320a1013edc';

final class FilteredTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          (FilteredTransactionTarget, String, int)
        > {
  FilteredTransactionsFamily._()
    : super(
        retry: null,
        name: r'filteredTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FilteredTransactionsProvider call(
    FilteredTransactionTarget target,
    String targetId,
    int limit,
  ) => FilteredTransactionsProvider._(
    argument: (target, targetId, limit),
    from: this,
  );

  @override
  String toString() => r'filteredTransactionsProvider';
}

@ProviderFor(FilteredTransactionsViewModel)
final filteredTransactionsViewModelProvider =
    FilteredTransactionsViewModelFamily._();

final class FilteredTransactionsViewModelProvider
    extends
        $NotifierProvider<
          FilteredTransactionsViewModel,
          FilteredTransactionsState
        > {
  FilteredTransactionsViewModelProvider._({
    required FilteredTransactionsViewModelFamily super.from,
    required (FilteredTransactionTarget, String) super.argument,
  }) : super(
         retry: null,
         name: r'filteredTransactionsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredTransactionsViewModelHash();

  @override
  String toString() {
    return r'filteredTransactionsViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  FilteredTransactionsViewModel create() => FilteredTransactionsViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilteredTransactionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilteredTransactionsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredTransactionsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredTransactionsViewModelHash() =>
    r'6c56f16ca96bfe0d7689ffc1d52f8ef4afcb6cf8';

final class FilteredTransactionsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          FilteredTransactionsViewModel,
          FilteredTransactionsState,
          FilteredTransactionsState,
          FilteredTransactionsState,
          (FilteredTransactionTarget, String)
        > {
  FilteredTransactionsViewModelFamily._()
    : super(
        retry: null,
        name: r'filteredTransactionsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FilteredTransactionsViewModelProvider call(
    FilteredTransactionTarget target,
    String targetId,
  ) => FilteredTransactionsViewModelProvider._(
    argument: (target, targetId),
    from: this,
  );

  @override
  String toString() => r'filteredTransactionsViewModelProvider';
}

abstract class _$FilteredTransactionsViewModel
    extends $Notifier<FilteredTransactionsState> {
  late final _$args = ref.$arg as (FilteredTransactionTarget, String);
  FilteredTransactionTarget get target => _$args.$1;
  String get targetId => _$args.$2;

  FilteredTransactionsState build(
    FilteredTransactionTarget target,
    String targetId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<FilteredTransactionsState, FilteredTransactionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FilteredTransactionsState, FilteredTransactionsState>,
              FilteredTransactionsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
