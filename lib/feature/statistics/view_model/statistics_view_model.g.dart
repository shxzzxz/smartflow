// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StatisticsViewModel)
final statisticsViewModelProvider = StatisticsViewModelProvider._();

final class StatisticsViewModelProvider
    extends $NotifierProvider<StatisticsViewModel, StatisticsControlState> {
  StatisticsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statisticsViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statisticsViewModelHash();

  @$internal
  @override
  StatisticsViewModel create() => StatisticsViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsControlState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsControlState>(value),
    );
  }
}

String _$statisticsViewModelHash() =>
    r'bc682367938580ab04e703cf89663169ed0fedd0';

abstract class _$StatisticsViewModel extends $Notifier<StatisticsControlState> {
  StatisticsControlState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<StatisticsControlState, StatisticsControlState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StatisticsControlState, StatisticsControlState>,
              StatisticsControlState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(statisticsPage)
final statisticsPageProvider = StatisticsPageProvider._();

final class StatisticsPageProvider
    extends
        $FunctionalProvider<
          StatisticsPageState,
          StatisticsPageState,
          StatisticsPageState
        >
    with $Provider<StatisticsPageState> {
  StatisticsPageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statisticsPageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statisticsPageHash();

  @$internal
  @override
  $ProviderElement<StatisticsPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsPageState create(Ref ref) {
    return statisticsPage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsPageState>(value),
    );
  }
}

String _$statisticsPageHash() => r'95b845fb5018e5a19c92a487d45f0ff3cffbdfe0';

@ProviderFor(statisticsCashflowReport)
final statisticsCashflowReportProvider = StatisticsCashflowReportFamily._();

final class StatisticsCashflowReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<CashflowReport>,
          CashflowReport,
          Stream<CashflowReport>
        >
    with $FutureModifier<CashflowReport>, $StreamProvider<CashflowReport> {
  StatisticsCashflowReportProvider._({
    required StatisticsCashflowReportFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsCashflowReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsCashflowReportHash();

  @override
  String toString() {
    return r'statisticsCashflowReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<CashflowReport> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CashflowReport> create(Ref ref) {
    final argument = this.argument as DateTime;
    return statisticsCashflowReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsCashflowReportProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsCashflowReportHash() =>
    r'3ca8e21a202dded28617e7c64c33c0273527f083';

final class StatisticsCashflowReportFamily extends $Family
    with $FunctionalFamilyOverride<Stream<CashflowReport>, DateTime> {
  StatisticsCashflowReportFamily._()
    : super(
        retry: null,
        name: r'statisticsCashflowReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsCashflowReportProvider call(DateTime visibleMonth) =>
      StatisticsCashflowReportProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'statisticsCashflowReportProvider';
}

@ProviderFor(statisticsBalanceReport)
final statisticsBalanceReportProvider = StatisticsBalanceReportFamily._();

final class StatisticsBalanceReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<BalanceReport>,
          BalanceReport,
          Stream<BalanceReport>
        >
    with $FutureModifier<BalanceReport>, $StreamProvider<BalanceReport> {
  StatisticsBalanceReportProvider._({
    required StatisticsBalanceReportFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsBalanceReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsBalanceReportHash();

  @override
  String toString() {
    return r'statisticsBalanceReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<BalanceReport> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BalanceReport> create(Ref ref) {
    final argument = this.argument as DateTime;
    return statisticsBalanceReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsBalanceReportProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsBalanceReportHash() =>
    r'1f4408a3b70dce6eccf3ce4d85509cd8e4ab7190';

final class StatisticsBalanceReportFamily extends $Family
    with $FunctionalFamilyOverride<Stream<BalanceReport>, DateTime> {
  StatisticsBalanceReportFamily._()
    : super(
        retry: null,
        name: r'statisticsBalanceReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsBalanceReportProvider call(DateTime visibleMonth) =>
      StatisticsBalanceReportProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'statisticsBalanceReportProvider';
}

@ProviderFor(statisticsContent)
final statisticsContentProvider = StatisticsContentFamily._();

final class StatisticsContentProvider
    extends
        $FunctionalProvider<
          StatisticsContentState,
          StatisticsContentState,
          StatisticsContentState
        >
    with $Provider<StatisticsContentState> {
  StatisticsContentProvider._({
    required StatisticsContentFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsContentHash();

  @override
  String toString() {
    return r'statisticsContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<StatisticsContentState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsContentState create(Ref ref) {
    final argument = this.argument as DateTime;
    return statisticsContent(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsContentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsContentHash() => r'6792df436155aa49f27de7f78f4d82d97600b525';

final class StatisticsContentFamily extends $Family
    with $FunctionalFamilyOverride<StatisticsContentState, DateTime> {
  StatisticsContentFamily._()
    : super(
        retry: null,
        name: r'statisticsContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsContentProvider call(DateTime visibleMonth) =>
      StatisticsContentProvider._(argument: visibleMonth, from: this);

  @override
  String toString() => r'statisticsContentProvider';
}

@ProviderFor(statisticsTransactions)
final statisticsTransactionsProvider = StatisticsTransactionsFamily._();

final class StatisticsTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  StatisticsTransactionsProvider._({
    required StatisticsTransactionsFamily super.from,
    required ({
      String accountIdsKey,
      DateTime? occurredFrom,
      DateTime occurredUntil,
      StatisticsDrilldownScope scope,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'statisticsTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsTransactionsHash();

  @override
  String toString() {
    return r'statisticsTransactionsProvider'
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
    final argument =
        this.argument
            as ({
              String accountIdsKey,
              DateTime? occurredFrom,
              DateTime occurredUntil,
              StatisticsDrilldownScope scope,
            });
    return statisticsTransactions(
      ref,
      accountIdsKey: argument.accountIdsKey,
      occurredFrom: argument.occurredFrom,
      occurredUntil: argument.occurredUntil,
      scope: argument.scope,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsTransactionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsTransactionsHash() =>
    r'95834854e4d7635d7cc8f921dcafc28a584906bc';

final class StatisticsTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          ({
            String accountIdsKey,
            DateTime? occurredFrom,
            DateTime occurredUntil,
            StatisticsDrilldownScope scope,
          })
        > {
  StatisticsTransactionsFamily._()
    : super(
        retry: null,
        name: r'statisticsTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsTransactionsProvider call({
    required String accountIdsKey,
    required DateTime? occurredFrom,
    required DateTime occurredUntil,
    required StatisticsDrilldownScope scope,
  }) => StatisticsTransactionsProvider._(
    argument: (
      accountIdsKey: accountIdsKey,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
    ),
    from: this,
  );

  @override
  String toString() => r'statisticsTransactionsProvider';
}

@ProviderFor(statisticsTransactionsContent)
final statisticsTransactionsContentProvider =
    StatisticsTransactionsContentFamily._();

final class StatisticsTransactionsContentProvider
    extends
        $FunctionalProvider<
          StatisticsTransactionsContentState,
          StatisticsTransactionsContentState,
          StatisticsTransactionsContentState
        >
    with $Provider<StatisticsTransactionsContentState> {
  StatisticsTransactionsContentProvider._({
    required StatisticsTransactionsContentFamily super.from,
    required ({
      String accountIdsKey,
      DateTime? occurredFrom,
      DateTime occurredUntil,
      StatisticsDrilldownScope scope,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'statisticsTransactionsContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsTransactionsContentHash();

  @override
  String toString() {
    return r'statisticsTransactionsContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<StatisticsTransactionsContentState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsTransactionsContentState create(Ref ref) {
    final argument =
        this.argument
            as ({
              String accountIdsKey,
              DateTime? occurredFrom,
              DateTime occurredUntil,
              StatisticsDrilldownScope scope,
            });
    return statisticsTransactionsContent(
      ref,
      accountIdsKey: argument.accountIdsKey,
      occurredFrom: argument.occurredFrom,
      occurredUntil: argument.occurredUntil,
      scope: argument.scope,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsTransactionsContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsTransactionsContentState>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsTransactionsContentProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsTransactionsContentHash() =>
    r'801905112531dea15426a659db5dd01319ba51b9';

final class StatisticsTransactionsContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          StatisticsTransactionsContentState,
          ({
            String accountIdsKey,
            DateTime? occurredFrom,
            DateTime occurredUntil,
            StatisticsDrilldownScope scope,
          })
        > {
  StatisticsTransactionsContentFamily._()
    : super(
        retry: null,
        name: r'statisticsTransactionsContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsTransactionsContentProvider call({
    required String accountIdsKey,
    required DateTime? occurredFrom,
    required DateTime occurredUntil,
    required StatisticsDrilldownScope scope,
  }) => StatisticsTransactionsContentProvider._(
    argument: (
      accountIdsKey: accountIdsKey,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
    ),
    from: this,
  );

  @override
  String toString() => r'statisticsTransactionsContentProvider';
}
