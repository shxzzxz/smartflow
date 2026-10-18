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
    r'23fe79da1afddc980ff350befce049bda929e57f';

abstract class _$StatisticsViewModel extends $Notifier<StatisticsControlState> {
  StatisticsControlState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
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

String _$statisticsPageHash() => r'f5cb07b5a7cbb0f873225c86417543e932f026ed';

@ProviderFor(statisticsRangeReport)
final statisticsRangeReportProvider = StatisticsRangeReportFamily._();

final class StatisticsRangeReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<StatisticsRangeReport>,
          StatisticsRangeReport,
          Stream<StatisticsRangeReport>
        >
    with
        $FutureModifier<StatisticsRangeReport>,
        $StreamProvider<StatisticsRangeReport> {
  StatisticsRangeReportProvider._({
    required StatisticsRangeReportFamily super.from,
    required (DateTime, DateTime, int, DateTime?, DateTime?) super.argument,
  }) : super(
         retry: null,
         name: r'statisticsRangeReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsRangeReportHash();

  @override
  String toString() {
    return r'statisticsRangeReportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<StatisticsRangeReport> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StatisticsRangeReport> create(Ref ref) {
    final argument =
        this.argument as (DateTime, DateTime, int, DateTime?, DateTime?);
    return statisticsRangeReport(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
      argument.$4,
      argument.$5,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsRangeReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsRangeReportHash() =>
    r'7d96873c709954f9a6fc735398d886b3767b9cff';

final class StatisticsRangeReportFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<StatisticsRangeReport>,
          (DateTime, DateTime, int, DateTime?, DateTime?)
        > {
  StatisticsRangeReportFamily._()
    : super(
        retry: null,
        name: r'statisticsRangeReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsRangeReportProvider call(
    DateTime from,
    DateTime until,
    int balancePointIntervalDays,
    DateTime? comparisonFrom,
    DateTime? comparisonUntil,
  ) => StatisticsRangeReportProvider._(
    argument: (
      from,
      until,
      balancePointIntervalDays,
      comparisonFrom,
      comparisonUntil,
    ),
    from: this,
  );

  @override
  String toString() => r'statisticsRangeReportProvider';
}

@ProviderFor(statisticsRangeContent)
final statisticsRangeContentProvider = StatisticsRangeContentFamily._();

final class StatisticsRangeContentProvider
    extends
        $FunctionalProvider<
          StatisticsContentState,
          StatisticsContentState,
          StatisticsContentState
        >
    with $Provider<StatisticsContentState> {
  StatisticsRangeContentProvider._({
    required StatisticsRangeContentFamily super.from,
    required (DateTime, DateTime, int) super.argument,
  }) : super(
         retry: null,
         name: r'statisticsRangeContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsRangeContentHash();

  @override
  String toString() {
    return r'statisticsRangeContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<StatisticsContentState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsContentState create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime, int);
    return statisticsRangeContent(ref, argument.$1, argument.$2, argument.$3);
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
    return other is StatisticsRangeContentProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsRangeContentHash() =>
    r'3fabf77a023375258cb42d522cd9d46b22467081';

final class StatisticsRangeContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          StatisticsContentState,
          (DateTime, DateTime, int)
        > {
  StatisticsRangeContentFamily._()
    : super(
        retry: null,
        name: r'statisticsRangeContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsRangeContentProvider call(
    DateTime from,
    DateTime until,
    int balancePointIntervalDays,
  ) => StatisticsRangeContentProvider._(
    argument: (from, until, balancePointIntervalDays),
    from: this,
  );

  @override
  String toString() => r'statisticsRangeContentProvider';
}

@ProviderFor(statisticsTransactions)
final statisticsTransactionsProvider = StatisticsTransactionsFamily._();

final class StatisticsTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionReadModel>>,
          List<TransactionReadModel>,
          Stream<List<TransactionReadModel>>
        >
    with
        $FutureModifier<List<TransactionReadModel>>,
        $StreamProvider<List<TransactionReadModel>> {
  StatisticsTransactionsProvider._({
    required StatisticsTransactionsFamily super.from,
    required ({
      CategorySelection? category,
      String? settlementAccountId,
      String? tagId,
      bool untaggedOnly,
      DateTime? occurredFrom,
      DateTime occurredUntil,
      StatisticsDrilldownScope scope,
      AccountType? accountType,
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
  $StreamProviderElement<List<TransactionReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TransactionReadModel>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              CategorySelection? category,
              String? settlementAccountId,
              String? tagId,
              bool untaggedOnly,
              DateTime? occurredFrom,
              DateTime occurredUntil,
              StatisticsDrilldownScope scope,
              AccountType? accountType,
            });
    return statisticsTransactions(
      ref,
      category: argument.category,
      settlementAccountId: argument.settlementAccountId,
      tagId: argument.tagId,
      untaggedOnly: argument.untaggedOnly,
      occurredFrom: argument.occurredFrom,
      occurredUntil: argument.occurredUntil,
      scope: argument.scope,
      accountType: argument.accountType,
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
    r'2f37d2daa53282f988b5d66656f592416f71b29e';

final class StatisticsTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionReadModel>>,
          ({
            CategorySelection? category,
            String? settlementAccountId,
            String? tagId,
            bool untaggedOnly,
            DateTime? occurredFrom,
            DateTime occurredUntil,
            StatisticsDrilldownScope scope,
            AccountType? accountType,
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
    required CategorySelection? category,
    required String? settlementAccountId,
    required String? tagId,
    required bool untaggedOnly,
    required DateTime? occurredFrom,
    required DateTime occurredUntil,
    required StatisticsDrilldownScope scope,
    AccountType? accountType,
  }) => StatisticsTransactionsProvider._(
    argument: (
      category: category,
      settlementAccountId: settlementAccountId,
      tagId: tagId,
      untaggedOnly: untaggedOnly,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
      accountType: accountType,
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
      CategorySelection? category,
      String? settlementAccountId,
      String? tagId,
      bool untaggedOnly,
      DateTime? occurredFrom,
      DateTime occurredUntil,
      StatisticsDrilldownScope scope,
      AccountType? accountType,
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
              CategorySelection? category,
              String? settlementAccountId,
              String? tagId,
              bool untaggedOnly,
              DateTime? occurredFrom,
              DateTime occurredUntil,
              StatisticsDrilldownScope scope,
              AccountType? accountType,
            });
    return statisticsTransactionsContent(
      ref,
      category: argument.category,
      settlementAccountId: argument.settlementAccountId,
      tagId: argument.tagId,
      untaggedOnly: argument.untaggedOnly,
      occurredFrom: argument.occurredFrom,
      occurredUntil: argument.occurredUntil,
      scope: argument.scope,
      accountType: argument.accountType,
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
    r'ee48f50de9c12739d6b41b254c754cc9c6a3f582';

final class StatisticsTransactionsContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          StatisticsTransactionsContentState,
          ({
            CategorySelection? category,
            String? settlementAccountId,
            String? tagId,
            bool untaggedOnly,
            DateTime? occurredFrom,
            DateTime occurredUntil,
            StatisticsDrilldownScope scope,
            AccountType? accountType,
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
    required CategorySelection? category,
    required String? settlementAccountId,
    required String? tagId,
    required bool untaggedOnly,
    required DateTime? occurredFrom,
    required DateTime occurredUntil,
    required StatisticsDrilldownScope scope,
    AccountType? accountType,
  }) => StatisticsTransactionsContentProvider._(
    argument: (
      category: category,
      settlementAccountId: settlementAccountId,
      tagId: tagId,
      untaggedOnly: untaggedOnly,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
      accountType: accountType,
    ),
    from: this,
  );

  @override
  String toString() => r'statisticsTransactionsContentProvider';
}
