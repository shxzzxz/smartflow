// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CalendarViewModel)
final calendarViewModelProvider = CalendarViewModelProvider._();

final class CalendarViewModelProvider
    extends $NotifierProvider<CalendarViewModel, CalendarPageState> {
  CalendarViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarViewModelHash();

  @$internal
  @override
  CalendarViewModel create() => CalendarViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarPageState>(value),
    );
  }
}

String _$calendarViewModelHash() => r'2da9c65fca5456dbc64104e8859fb28ffc194274';

abstract class _$CalendarViewModel extends $Notifier<CalendarPageState> {
  CalendarPageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CalendarPageState, CalendarPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarPageState, CalendarPageState>,
              CalendarPageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(calendarTransactions)
final calendarTransactionsProvider = CalendarTransactionsFamily._();

final class CalendarTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  CalendarTransactionsProvider._({
    required CalendarTransactionsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarTransactionsHash();

  @override
  String toString() {
    return r'calendarTransactionsProvider'
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
    return calendarTransactions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarTransactionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarTransactionsHash() =>
    r'2f460caecf89f589b913f50659b23f8550eceb02';

final class CalendarTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          DateTime
        > {
  CalendarTransactionsFamily._()
    : super(
        retry: null,
        name: r'calendarTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarTransactionsProvider call(DateTime selectedDate) =>
      CalendarTransactionsProvider._(argument: selectedDate, from: this);

  @override
  String toString() => r'calendarTransactionsProvider';
}

/// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
/// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。

@ProviderFor(CalendarTransactionFeedViewModel)
final calendarTransactionFeedViewModelProvider =
    CalendarTransactionFeedViewModelFamily._();

/// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
/// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。
final class CalendarTransactionFeedViewModelProvider
    extends
        $NotifierProvider<
          CalendarTransactionFeedViewModel,
          CalendarTransactionFeedState
        > {
  /// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
  /// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。
  CalendarTransactionFeedViewModelProvider._({
    required CalendarTransactionFeedViewModelFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarTransactionFeedViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarTransactionFeedViewModelHash();

  @override
  String toString() {
    return r'calendarTransactionFeedViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CalendarTransactionFeedViewModel create() =>
      CalendarTransactionFeedViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarTransactionFeedState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarTransactionFeedState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarTransactionFeedViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarTransactionFeedViewModelHash() =>
    r'8a604defc6a7410f057f8dde8c22c79980624868';

/// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
/// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。

final class CalendarTransactionFeedViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CalendarTransactionFeedViewModel,
          CalendarTransactionFeedState,
          CalendarTransactionFeedState,
          CalendarTransactionFeedState,
          DateTime
        > {
  CalendarTransactionFeedViewModelFamily._()
    : super(
        retry: null,
        name: r'calendarTransactionFeedViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
  /// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。

  CalendarTransactionFeedViewModelProvider call(DateTime selectedDate) =>
      CalendarTransactionFeedViewModelProvider._(
        argument: selectedDate,
        from: this,
      );

  @override
  String toString() => r'calendarTransactionFeedViewModelProvider';
}

/// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
/// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。

abstract class _$CalendarTransactionFeedViewModel
    extends $Notifier<CalendarTransactionFeedState> {
  late final _$args = ref.$arg as DateTime;
  DateTime get selectedDate => _$args;

  CalendarTransactionFeedState build(DateTime selectedDate);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<CalendarTransactionFeedState, CalendarTransactionFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                CalendarTransactionFeedState,
                CalendarTransactionFeedState
              >,
              CalendarTransactionFeedState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(calendarCashflowComparison)
final calendarCashflowComparisonProvider = CalendarCashflowComparisonFamily._();

final class CalendarCashflowComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<CashflowComparison>,
          CashflowComparison,
          Stream<CashflowComparison>
        >
    with
        $FutureModifier<CashflowComparison>,
        $StreamProvider<CashflowComparison> {
  CalendarCashflowComparisonProvider._({
    required CalendarCashflowComparisonFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarCashflowComparisonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarCashflowComparisonHash();

  @override
  String toString() {
    return r'calendarCashflowComparisonProvider'
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
    return calendarCashflowComparison(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarCashflowComparisonProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarCashflowComparisonHash() =>
    r'a8f05ef22cb15ee78ea86b95a5b60aa4168b5f5f';

final class CalendarCashflowComparisonFamily extends $Family
    with $FunctionalFamilyOverride<Stream<CashflowComparison>, DateTime> {
  CalendarCashflowComparisonFamily._()
    : super(
        retry: null,
        name: r'calendarCashflowComparisonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarCashflowComparisonProvider call(DateTime visibleMonth) =>
      CalendarCashflowComparisonProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'calendarCashflowComparisonProvider';
}

@ProviderFor(calendarDailyCashflowSummaries)
final calendarDailyCashflowSummariesProvider =
    CalendarDailyCashflowSummariesFamily._();

final class CalendarDailyCashflowSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyCashflowSummary>>,
          List<DailyCashflowSummary>,
          Stream<List<DailyCashflowSummary>>
        >
    with
        $FutureModifier<List<DailyCashflowSummary>>,
        $StreamProvider<List<DailyCashflowSummary>> {
  CalendarDailyCashflowSummariesProvider._({
    required CalendarDailyCashflowSummariesFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarDailyCashflowSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarDailyCashflowSummariesHash();

  @override
  String toString() {
    return r'calendarDailyCashflowSummariesProvider'
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
    return calendarDailyCashflowSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDailyCashflowSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarDailyCashflowSummariesHash() =>
    r'b19aa80b72833ff520cf84ea9ca2280eb974624f';

final class CalendarDailyCashflowSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<DailyCashflowSummary>>,
          DateTime
        > {
  CalendarDailyCashflowSummariesFamily._()
    : super(
        retry: null,
        name: r'calendarDailyCashflowSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarDailyCashflowSummariesProvider call(DateTime visibleMonth) =>
      CalendarDailyCashflowSummariesProvider._(
        argument: visibleMonth,
        from: this,
      );

  @override
  String toString() => r'calendarDailyCashflowSummariesProvider';
}

@ProviderFor(calendarCreditDueItems)
final calendarCreditDueItemsProvider = CalendarCreditDueItemsFamily._();

final class CalendarCreditDueItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CreditDueCalendarItemReadModel>>,
          List<CreditDueCalendarItemReadModel>,
          FutureOr<List<CreditDueCalendarItemReadModel>>
        >
    with
        $FutureModifier<List<CreditDueCalendarItemReadModel>>,
        $FutureProvider<List<CreditDueCalendarItemReadModel>> {
  CalendarCreditDueItemsProvider._({
    required CalendarCreditDueItemsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarCreditDueItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarCreditDueItemsHash();

  @override
  String toString() {
    return r'calendarCreditDueItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CreditDueCalendarItemReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CreditDueCalendarItemReadModel>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return calendarCreditDueItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarCreditDueItemsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarCreditDueItemsHash() =>
    r'05f273b2324b6edb08c56f097469486b72bfc779';

final class CalendarCreditDueItemsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<CreditDueCalendarItemReadModel>>,
          DateTime
        > {
  CalendarCreditDueItemsFamily._()
    : super(
        retry: null,
        name: r'calendarCreditDueItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarCreditDueItemsProvider call(DateTime visibleMonth) =>
      CalendarCreditDueItemsProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'calendarCreditDueItemsProvider';
}

@ProviderFor(calendarMonthlyBillSummaries)
final calendarMonthlyBillSummariesProvider =
    CalendarMonthlyBillSummariesFamily._();

final class CalendarMonthlyBillSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MonthlyBillSummaryReadModel>>,
          List<MonthlyBillSummaryReadModel>,
          FutureOr<List<MonthlyBillSummaryReadModel>>
        >
    with
        $FutureModifier<List<MonthlyBillSummaryReadModel>>,
        $FutureProvider<List<MonthlyBillSummaryReadModel>> {
  CalendarMonthlyBillSummariesProvider._({
    required CalendarMonthlyBillSummariesFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarMonthlyBillSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarMonthlyBillSummariesHash();

  @override
  String toString() {
    return r'calendarMonthlyBillSummariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MonthlyBillSummaryReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MonthlyBillSummaryReadModel>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return calendarMonthlyBillSummaries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarMonthlyBillSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarMonthlyBillSummariesHash() =>
    r'e36741f1153cb43b2c5d3f65b40beb5cb57e1057';

final class CalendarMonthlyBillSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MonthlyBillSummaryReadModel>>,
          DateTime
        > {
  CalendarMonthlyBillSummariesFamily._()
    : super(
        retry: null,
        name: r'calendarMonthlyBillSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarMonthlyBillSummariesProvider call(DateTime visibleMonth) =>
      CalendarMonthlyBillSummariesProvider._(
        argument: visibleMonth,
        from: this,
      );

  @override
  String toString() => r'calendarMonthlyBillSummariesProvider';
}

@ProviderFor(calendarContent)
final calendarContentProvider = CalendarContentFamily._();

final class CalendarContentProvider
    extends
        $FunctionalProvider<
          CalendarContentState,
          CalendarContentState,
          CalendarContentState
        >
    with $Provider<CalendarContentState> {
  CalendarContentProvider._({
    required CalendarContentFamily super.from,
    required ({
      DateTime visibleMonth,
      DateTime selectedDate,
      CalendarHeatMetric? heatMetric,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'calendarContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarContentHash();

  @override
  String toString() {
    return r'calendarContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<CalendarContentState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarContentState create(Ref ref) {
    final argument =
        this.argument
            as ({
              DateTime visibleMonth,
              DateTime selectedDate,
              CalendarHeatMetric? heatMetric,
            });
    return calendarContent(
      ref,
      visibleMonth: argument.visibleMonth,
      selectedDate: argument.selectedDate,
      heatMetric: argument.heatMetric,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarContentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarContentHash() => r'3a33091423070d7f8904a0c65ffb932bd7c81de9';

final class CalendarContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          CalendarContentState,
          ({
            DateTime visibleMonth,
            DateTime selectedDate,
            CalendarHeatMetric? heatMetric,
          })
        > {
  CalendarContentFamily._()
    : super(
        retry: null,
        name: r'calendarContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarContentProvider call({
    required DateTime visibleMonth,
    required DateTime selectedDate,
    CalendarHeatMetric? heatMetric,
  }) => CalendarContentProvider._(
    argument: (
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      heatMetric: heatMetric,
    ),
    from: this,
  );

  @override
  String toString() => r'calendarContentProvider';
}
