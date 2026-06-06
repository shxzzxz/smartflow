// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeViewModel)
final homeViewModelProvider = HomeViewModelProvider._();

final class HomeViewModelProvider
    extends $NotifierProvider<HomeViewModel, HomePageState> {
  HomeViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeViewModelHash();

  @$internal
  @override
  HomeViewModel create() => HomeViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomePageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomePageState>(value),
    );
  }
}

String _$homeViewModelHash() => r'f7a2c29fc19f34bf8086e2bca8f5f1e62ab7a86d';

abstract class _$HomeViewModel extends $Notifier<HomePageState> {
  HomePageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HomePageState, HomePageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HomePageState, HomePageState>,
              HomePageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(homeTransactions)
final homeTransactionsProvider = HomeTransactionsFamily._();

final class HomeTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  HomeTransactionsProvider._({
    required HomeTransactionsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeTransactionsHash();

  @override
  String toString() {
    return r'homeTransactionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TransactionListReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TransactionListReadModel>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return homeTransactions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeTransactionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeTransactionsHash() => r'ae59e639e51c58b89dc52645fdd15f59ba408730';

final class HomeTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          DateTime
        > {
  HomeTransactionsFamily._()
    : super(
        retry: null,
        name: r'homeTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeTransactionsProvider call(DateTime visibleMonth) =>
      HomeTransactionsProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'homeTransactionsProvider';
}

@ProviderFor(homeCashflowComparison)
final homeCashflowComparisonProvider = HomeCashflowComparisonFamily._();

final class HomeCashflowComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<CashflowComparison>,
          CashflowComparison,
          Stream<CashflowComparison>
        >
    with
        $FutureModifier<CashflowComparison>,
        $StreamProvider<CashflowComparison> {
  HomeCashflowComparisonProvider._({
    required HomeCashflowComparisonFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeCashflowComparisonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeCashflowComparisonHash();

  @override
  String toString() {
    return r'homeCashflowComparisonProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<CashflowComparison> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CashflowComparison> create(Ref ref) {
    final argument = this.argument as DateTime;
    return homeCashflowComparison(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeCashflowComparisonProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeCashflowComparisonHash() =>
    r'3605995dd7aecac8a9095800e2e611f12af48e78';

final class HomeCashflowComparisonFamily extends $Family
    with $FunctionalFamilyOverride<Stream<CashflowComparison>, DateTime> {
  HomeCashflowComparisonFamily._()
    : super(
        retry: null,
        name: r'homeCashflowComparisonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeCashflowComparisonProvider call(DateTime visibleMonth) =>
      HomeCashflowComparisonProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'homeCashflowComparisonProvider';
}

@ProviderFor(homeDailyCashflowSummaries)
final homeDailyCashflowSummariesProvider = HomeDailyCashflowSummariesFamily._();

final class HomeDailyCashflowSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyCashflowSummary>>,
          List<DailyCashflowSummary>,
          Stream<List<DailyCashflowSummary>>
        >
    with
        $FutureModifier<List<DailyCashflowSummary>>,
        $StreamProvider<List<DailyCashflowSummary>> {
  HomeDailyCashflowSummariesProvider._({
    required HomeDailyCashflowSummariesFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeDailyCashflowSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeDailyCashflowSummariesHash();

  @override
  String toString() {
    return r'homeDailyCashflowSummariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<DailyCashflowSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DailyCashflowSummary>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return homeDailyCashflowSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeDailyCashflowSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeDailyCashflowSummariesHash() =>
    r'94eb9154a437f4e3b14a1db7549fdc13d4bbff40';

final class HomeDailyCashflowSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<DailyCashflowSummary>>,
          DateTime
        > {
  HomeDailyCashflowSummariesFamily._()
    : super(
        retry: null,
        name: r'homeDailyCashflowSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeDailyCashflowSummariesProvider call(DateTime visibleMonth) =>
      HomeDailyCashflowSummariesProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'homeDailyCashflowSummariesProvider';
}

@ProviderFor(homeContent)
final homeContentProvider = HomeContentFamily._();

final class HomeContentProvider
    extends
        $FunctionalProvider<
          HomeContentState,
          HomeContentState,
          HomeContentState
        >
    with $Provider<HomeContentState> {
  HomeContentProvider._({
    required HomeContentFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeContentHash();

  @override
  String toString() {
    return r'homeContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<HomeContentState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HomeContentState create(Ref ref) {
    final argument = this.argument as DateTime;
    return homeContent(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeContentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeContentHash() => r'c808baf878586cb3ea00533e6a948f2664fd8523';

final class HomeContentFamily extends $Family
    with $FunctionalFamilyOverride<HomeContentState, DateTime> {
  HomeContentFamily._()
    : super(
        retry: null,
        name: r'homeContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeContentProvider call(DateTime visibleMonth) =>
      HomeContentProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'homeContentProvider';
}
