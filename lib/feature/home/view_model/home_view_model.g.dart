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

String _$homeViewModelHash() => r'0d0352b1457886376488463b89a3a813a47ce858';

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

String _$homeTransactionsHash() => r'29ea8b14e9a6e0285f13a2570198bfabc97be80d';

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

@ProviderFor(HomeTransactionFeedViewModel)
final homeTransactionFeedViewModelProvider =
    HomeTransactionFeedViewModelFamily._();

final class HomeTransactionFeedViewModelProvider
    extends
        $NotifierProvider<
          HomeTransactionFeedViewModel,
          HomeTransactionFeedState
        > {
  HomeTransactionFeedViewModelProvider._({
    required HomeTransactionFeedViewModelFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'homeTransactionFeedViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeTransactionFeedViewModelHash();

  @override
  String toString() {
    return r'homeTransactionFeedViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HomeTransactionFeedViewModel create() => HomeTransactionFeedViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeTransactionFeedState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeTransactionFeedState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeTransactionFeedViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeTransactionFeedViewModelHash() =>
    r'9ab568952f1fea3889eb0eefdcb3037f2209daca';

final class HomeTransactionFeedViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          HomeTransactionFeedViewModel,
          HomeTransactionFeedState,
          HomeTransactionFeedState,
          HomeTransactionFeedState,
          DateTime
        > {
  HomeTransactionFeedViewModelFamily._()
    : super(
        retry: null,
        name: r'homeTransactionFeedViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeTransactionFeedViewModelProvider call(DateTime visibleMonth) =>
      HomeTransactionFeedViewModelProvider._(
        argument: visibleMonth,
        from: this,
      );

  @override
  String toString() => r'homeTransactionFeedViewModelProvider';
}

abstract class _$HomeTransactionFeedViewModel
    extends $Notifier<HomeTransactionFeedState> {
  late final _$args = ref.$arg as DateTime;
  DateTime get visibleMonth => _$args;

  HomeTransactionFeedState build(DateTime visibleMonth);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<HomeTransactionFeedState, HomeTransactionFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HomeTransactionFeedState, HomeTransactionFeedState>,
              HomeTransactionFeedState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
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

@ProviderFor(homeFilterOptions)
final homeFilterOptionsProvider = HomeFilterOptionsProvider._();

final class HomeFilterOptionsProvider
    extends
        $FunctionalProvider<
          HomeFilterOptionsState,
          HomeFilterOptionsState,
          HomeFilterOptionsState
        >
    with $Provider<HomeFilterOptionsState> {
  HomeFilterOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFilterOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFilterOptionsHash();

  @$internal
  @override
  $ProviderElement<HomeFilterOptionsState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HomeFilterOptionsState create(Ref ref) {
    return homeFilterOptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeFilterOptionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeFilterOptionsState>(value),
    );
  }
}

String _$homeFilterOptionsHash() => r'ccce923b9a044181a8dc7560d382d02bd89d202d';

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

String _$homeContentHash() => r'ef71552ddc13eb0aee7831f588d1fa863ef14683';

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
