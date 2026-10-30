// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installmentContractsByAccount)
final installmentContractsByAccountProvider =
    InstallmentContractsByAccountFamily._();

final class InstallmentContractsByAccountProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstallmentContractReadModel>>,
          List<InstallmentContractReadModel>,
          FutureOr<List<InstallmentContractReadModel>>
        >
    with
        $FutureModifier<List<InstallmentContractReadModel>>,
        $FutureProvider<List<InstallmentContractReadModel>> {
  InstallmentContractsByAccountProvider._({
    required InstallmentContractsByAccountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentContractsByAccountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentContractsByAccountHash();

  @override
  String toString() {
    return r'installmentContractsByAccountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<InstallmentContractReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentContractReadModel>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentContractsByAccount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentContractsByAccountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentContractsByAccountHash() =>
    r'35d6f7f2c53a4b64802036e27e294876cc1be7d9';

final class InstallmentContractsByAccountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<InstallmentContractReadModel>>,
          String
        > {
  InstallmentContractsByAccountFamily._()
    : super(
        retry: null,
        name: r'installmentContractsByAccountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentContractsByAccountProvider call(String accountId) =>
      InstallmentContractsByAccountProvider._(argument: accountId, from: this);

  @override
  String toString() => r'installmentContractsByAccountProvider';
}

@ProviderFor(installmentContract)
final installmentContractProvider = InstallmentContractFamily._();

final class InstallmentContractProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallmentContractReadModel?>,
          InstallmentContractReadModel?,
          FutureOr<InstallmentContractReadModel?>
        >
    with
        $FutureModifier<InstallmentContractReadModel?>,
        $FutureProvider<InstallmentContractReadModel?> {
  InstallmentContractProvider._({
    required InstallmentContractFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentContractProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentContractHash();

  @override
  String toString() {
    return r'installmentContractProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallmentContractReadModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentContractReadModel?> create(Ref ref) {
    final argument = this.argument as String;
    return installmentContract(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentContractProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentContractHash() =>
    r'87d89acb8e0102dbcde94a3bc9e0793855315bb2';

final class InstallmentContractFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<InstallmentContractReadModel?>,
          String
        > {
  InstallmentContractFamily._()
    : super(
        retry: null,
        name: r'installmentContractProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentContractProvider call(String contractId) =>
      InstallmentContractProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentContractProvider';
}

@ProviderFor(installmentSchedules)
final installmentSchedulesProvider = InstallmentSchedulesFamily._();

final class InstallmentSchedulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstallmentScheduleReadModel>>,
          List<InstallmentScheduleReadModel>,
          FutureOr<List<InstallmentScheduleReadModel>>
        >
    with
        $FutureModifier<List<InstallmentScheduleReadModel>>,
        $FutureProvider<List<InstallmentScheduleReadModel>> {
  InstallmentSchedulesProvider._({
    required InstallmentSchedulesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentSchedulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentSchedulesHash();

  @override
  String toString() {
    return r'installmentSchedulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<InstallmentScheduleReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentScheduleReadModel>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentSchedules(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentSchedulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentSchedulesHash() =>
    r'd1ab5c406ecac7411558f5874d81451b1243cec1';

final class InstallmentSchedulesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<InstallmentScheduleReadModel>>,
          String
        > {
  InstallmentSchedulesFamily._()
    : super(
        retry: null,
        name: r'installmentSchedulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentSchedulesProvider call(String contractId) =>
      InstallmentSchedulesProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentSchedulesProvider';
}

@ProviderFor(installmentActivities)
final installmentActivitiesProvider = InstallmentActivitiesFamily._();

final class InstallmentActivitiesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContractActivity>>,
          List<ContractActivity>,
          FutureOr<List<ContractActivity>>
        >
    with
        $FutureModifier<List<ContractActivity>>,
        $FutureProvider<List<ContractActivity>> {
  InstallmentActivitiesProvider._({
    required InstallmentActivitiesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentActivitiesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentActivitiesHash();

  @override
  String toString() {
    return r'installmentActivitiesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContractActivity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContractActivity>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentActivities(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentActivitiesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentActivitiesHash() =>
    r'b3c74cce4de67503ba3900a197bd1c5bedbe7fa8';

final class InstallmentActivitiesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContractActivity>>, String> {
  InstallmentActivitiesFamily._()
    : super(
        retry: null,
        name: r'installmentActivitiesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentActivitiesProvider call(String contractId) =>
      InstallmentActivitiesProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentActivitiesProvider';
}

/// 按合同与全部还款计划计算合同指标。

@ProviderFor(installmentMetrics)
final installmentMetricsProvider = InstallmentMetricsFamily._();

/// 按合同与全部还款计划计算合同指标。

final class InstallmentMetricsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContractMetrics>,
          ContractMetrics,
          FutureOr<ContractMetrics>
        >
    with $FutureModifier<ContractMetrics>, $FutureProvider<ContractMetrics> {
  /// 按合同与全部还款计划计算合同指标。
  InstallmentMetricsProvider._({
    required InstallmentMetricsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentMetricsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentMetricsHash();

  @override
  String toString() {
    return r'installmentMetricsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ContractMetrics> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContractMetrics> create(Ref ref) {
    final argument = this.argument as String;
    return installmentMetrics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentMetricsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentMetricsHash() =>
    r'f8521ef992f2192c62f38328be8c287fd859d4b6';

/// 按合同与全部还款计划计算合同指标。

final class InstallmentMetricsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ContractMetrics>, String> {
  InstallmentMetricsFamily._()
    : super(
        retry: null,
        name: r'installmentMetricsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按合同与全部还款计划计算合同指标。

  InstallmentMetricsProvider call(String contractId) =>
      InstallmentMetricsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentMetricsProvider';
}
