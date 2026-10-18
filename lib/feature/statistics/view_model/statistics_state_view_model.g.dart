// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_state_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(statisticsCurrentBalanceReport)
final statisticsCurrentBalanceReportProvider =
    StatisticsCurrentBalanceReportFamily._();

final class StatisticsCurrentBalanceReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<BalanceReport>,
          BalanceReport,
          Stream<BalanceReport>
        >
    with $FutureModifier<BalanceReport>, $StreamProvider<BalanceReport> {
  StatisticsCurrentBalanceReportProvider._({
    required StatisticsCurrentBalanceReportFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsCurrentBalanceReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsCurrentBalanceReportHash();

  @override
  String toString() {
    return r'statisticsCurrentBalanceReportProvider'
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
    return statisticsCurrentBalanceReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsCurrentBalanceReportProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsCurrentBalanceReportHash() =>
    r'4b928371b622a9da6de09d8cee3623e03d91b561';

final class StatisticsCurrentBalanceReportFamily extends $Family
    with $FunctionalFamilyOverride<Stream<BalanceReport>, DateTime> {
  StatisticsCurrentBalanceReportFamily._()
    : super(
        retry: null,
        name: r'statisticsCurrentBalanceReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsCurrentBalanceReportProvider call(DateTime asOf) =>
      StatisticsCurrentBalanceReportProvider._(argument: asOf, from: this);

  @override
  String toString() => r'statisticsCurrentBalanceReportProvider';
}

@ProviderFor(statisticsStateContent)
final statisticsStateContentProvider = StatisticsStateContentFamily._();

final class StatisticsStateContentProvider
    extends
        $FunctionalProvider<
          StatisticsStateContentState,
          StatisticsStateContentState,
          StatisticsStateContentState
        >
    with $Provider<StatisticsStateContentState> {
  StatisticsStateContentProvider._({
    required StatisticsStateContentFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsStateContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsStateContentHash();

  @override
  String toString() {
    return r'statisticsStateContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<StatisticsStateContentState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsStateContentState create(Ref ref) {
    final argument = this.argument as DateTime;
    return statisticsStateContent(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsStateContentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsStateContentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsStateContentProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsStateContentHash() =>
    r'08c7ffea1070fe62b80df038c4e833f74a8c2706';

final class StatisticsStateContentFamily extends $Family
    with $FunctionalFamilyOverride<StatisticsStateContentState, DateTime> {
  StatisticsStateContentFamily._()
    : super(
        retry: null,
        name: r'statisticsStateContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsStateContentProvider call(DateTime asOf) =>
      StatisticsStateContentProvider._(argument: asOf, from: this);

  @override
  String toString() => r'statisticsStateContentProvider';
}

@ProviderFor(statisticsInstallments)
final statisticsInstallmentsProvider = StatisticsInstallmentsFamily._();

final class StatisticsInstallmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<StatisticsInstallmentsPresentation>,
          StatisticsInstallmentsPresentation,
          Stream<StatisticsInstallmentsPresentation>
        >
    with
        $FutureModifier<StatisticsInstallmentsPresentation>,
        $StreamProvider<StatisticsInstallmentsPresentation> {
  StatisticsInstallmentsProvider._({
    required StatisticsInstallmentsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'statisticsInstallmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$statisticsInstallmentsHash();

  @override
  String toString() {
    return r'statisticsInstallmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<StatisticsInstallmentsPresentation> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StatisticsInstallmentsPresentation> create(Ref ref) {
    final argument = this.argument as DateTime;
    return statisticsInstallments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StatisticsInstallmentsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$statisticsInstallmentsHash() =>
    r'758fe2e14ea23da89bb7b84163ce8babc2416826';

final class StatisticsInstallmentsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<StatisticsInstallmentsPresentation>,
          DateTime
        > {
  StatisticsInstallmentsFamily._()
    : super(
        retry: null,
        name: r'statisticsInstallmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StatisticsInstallmentsProvider call(DateTime asOf) =>
      StatisticsInstallmentsProvider._(argument: asOf, from: this);

  @override
  String toString() => r'statisticsInstallmentsProvider';
}
