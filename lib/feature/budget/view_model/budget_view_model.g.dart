// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BudgetViewModel)
final budgetViewModelProvider = BudgetViewModelFamily._();

final class BudgetViewModelProvider
    extends $NotifierProvider<BudgetViewModel, BudgetControlState> {
  BudgetViewModelProvider._({
    required BudgetViewModelFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'budgetViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$budgetViewModelHash();

  @override
  String toString() {
    return r'budgetViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BudgetViewModel create() => BudgetViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetControlState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetControlState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$budgetViewModelHash() => r'7580cea1a526d38a5ecf06045404bb7fa495e553';

final class BudgetViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          BudgetViewModel,
          BudgetControlState,
          BudgetControlState,
          BudgetControlState,
          DateTime?
        > {
  BudgetViewModelFamily._()
    : super(
        retry: null,
        name: r'budgetViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BudgetViewModelProvider call(DateTime? initialMonth) =>
      BudgetViewModelProvider._(argument: initialMonth, from: this);

  @override
  String toString() => r'budgetViewModelProvider';
}

abstract class _$BudgetViewModel extends $Notifier<BudgetControlState> {
  late final _$args = ref.$arg as DateTime?;
  DateTime? get initialMonth => _$args;

  BudgetControlState build(DateTime? initialMonth);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BudgetControlState, BudgetControlState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BudgetControlState, BudgetControlState>,
              BudgetControlState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(budgetPage)
final budgetPageProvider = BudgetPageFamily._();

final class BudgetPageProvider
    extends
        $FunctionalProvider<BudgetPageState, BudgetPageState, BudgetPageState>
    with $Provider<BudgetPageState> {
  BudgetPageProvider._({
    required BudgetPageFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'budgetPageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$budgetPageHash();

  @override
  String toString() {
    return r'budgetPageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BudgetPageState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BudgetPageState create(Ref ref) {
    final argument = this.argument as DateTime?;
    return budgetPage(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetPageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$budgetPageHash() => r'5cd65449af0f426946f38805a2c495683b95c385';

final class BudgetPageFamily extends $Family
    with $FunctionalFamilyOverride<BudgetPageState, DateTime?> {
  BudgetPageFamily._()
    : super(
        retry: null,
        name: r'budgetPageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BudgetPageProvider call(DateTime? initialMonth) =>
      BudgetPageProvider._(argument: initialMonth, from: this);

  @override
  String toString() => r'budgetPageProvider';
}

@ProviderFor(budgetCategoryTransactions)
final budgetCategoryTransactionsProvider = BudgetCategoryTransactionsFamily._();

final class BudgetCategoryTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  BudgetCategoryTransactionsProvider._({
    required BudgetCategoryTransactionsFamily super.from,
    required (String, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'budgetCategoryTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$budgetCategoryTransactionsHash();

  @override
  String toString() {
    return r'budgetCategoryTransactionsProvider'
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
    final argument = this.argument as (String, DateTime);
    return budgetCategoryTransactions(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetCategoryTransactionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$budgetCategoryTransactionsHash() =>
    r'dd44ce048ab5ea3d32b102cd0606da0579e2e2d2';

final class BudgetCategoryTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          (String, DateTime)
        > {
  BudgetCategoryTransactionsFamily._()
    : super(
        retry: null,
        name: r'budgetCategoryTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BudgetCategoryTransactionsProvider call(String categoryId, DateTime month) =>
      BudgetCategoryTransactionsProvider._(
        argument: (categoryId, month),
        from: this,
      );

  @override
  String toString() => r'budgetCategoryTransactionsProvider';
}

@ProviderFor(budgetDetailPage)
final budgetDetailPageProvider = BudgetDetailPageFamily._();

final class BudgetDetailPageProvider
    extends
        $FunctionalProvider<
          BudgetDetailPageState,
          BudgetDetailPageState,
          BudgetDetailPageState
        >
    with $Provider<BudgetDetailPageState> {
  BudgetDetailPageProvider._({
    required BudgetDetailPageFamily super.from,
    required (String, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'budgetDetailPageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$budgetDetailPageHash();

  @override
  String toString() {
    return r'budgetDetailPageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<BudgetDetailPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BudgetDetailPageState create(Ref ref) {
    final argument = this.argument as (String, DateTime);
    return budgetDetailPage(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetDetailPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetDetailPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetDetailPageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$budgetDetailPageHash() => r'e37b00d2eb7d1a7f51ee2c62dbb1357f79c38877';

final class BudgetDetailPageFamily extends $Family
    with $FunctionalFamilyOverride<BudgetDetailPageState, (String, DateTime)> {
  BudgetDetailPageFamily._()
    : super(
        retry: null,
        name: r'budgetDetailPageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BudgetDetailPageProvider call(String budgetId, DateTime month) =>
      BudgetDetailPageProvider._(argument: (budgetId, month), from: this);

  @override
  String toString() => r'budgetDetailPageProvider';
}
