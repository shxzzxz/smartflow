// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installmentsByAccount)
final installmentsByAccountProvider = InstallmentsByAccountFamily._();

final class InstallmentsByAccountProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstallmentDTO>>,
          List<InstallmentDTO>,
          FutureOr<List<InstallmentDTO>>
        >
    with
        $FutureModifier<List<InstallmentDTO>>,
        $FutureProvider<List<InstallmentDTO>> {
  InstallmentsByAccountProvider._({
    required InstallmentsByAccountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentsByAccountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentsByAccountHash();

  @override
  String toString() {
    return r'installmentsByAccountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<InstallmentDTO>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentDTO>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentsByAccount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentsByAccountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentsByAccountHash() =>
    r'4e19878f25de856abd6a73e9bdf1693e05f21e2a';

final class InstallmentsByAccountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<InstallmentDTO>>, String> {
  InstallmentsByAccountFamily._()
    : super(
        retry: null,
        name: r'installmentsByAccountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentsByAccountProvider call(String accountId) =>
      InstallmentsByAccountProvider._(argument: accountId, from: this);

  @override
  String toString() => r'installmentsByAccountProvider';
}

@ProviderFor(installment)
final installmentProvider = InstallmentFamily._();

final class InstallmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallmentDTO?>,
          InstallmentDTO?,
          FutureOr<InstallmentDTO?>
        >
    with $FutureModifier<InstallmentDTO?>, $FutureProvider<InstallmentDTO?> {
  InstallmentProvider._({
    required InstallmentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentHash();

  @override
  String toString() {
    return r'installmentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallmentDTO?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentDTO?> create(Ref ref) {
    final argument = this.argument as String;
    return installment(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentHash() => r'093478a443a52b06a34990c76aee1719affb02eb';

final class InstallmentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InstallmentDTO?>, String> {
  InstallmentFamily._()
    : super(
        retry: null,
        name: r'installmentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentProvider call(String installmentId) =>
      InstallmentProvider._(argument: installmentId, from: this);

  @override
  String toString() => r'installmentProvider';
}

@ProviderFor(installmentDetail)
final installmentDetailProvider = InstallmentDetailFamily._();

final class InstallmentDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallmentDetailDTO?>,
          InstallmentDetailDTO?,
          FutureOr<InstallmentDetailDTO?>
        >
    with
        $FutureModifier<InstallmentDetailDTO?>,
        $FutureProvider<InstallmentDetailDTO?> {
  InstallmentDetailProvider._({
    required InstallmentDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentDetailHash();

  @override
  String toString() {
    return r'installmentDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallmentDetailDTO?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentDetailDTO?> create(Ref ref) {
    final argument = this.argument as String;
    return installmentDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentDetailHash() => r'80883b1a157e1e6ee864059c945e9e0c97eddb26';

final class InstallmentDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InstallmentDetailDTO?>, String> {
  InstallmentDetailFamily._()
    : super(
        retry: null,
        name: r'installmentDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentDetailProvider call(String installmentId) =>
      InstallmentDetailProvider._(argument: installmentId, from: this);

  @override
  String toString() => r'installmentDetailProvider';
}

@ProviderFor(installmentRepricing)
final installmentRepricingProvider = InstallmentRepricingFamily._();

final class InstallmentRepricingProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallmentRepricingDTO?>,
          InstallmentRepricingDTO?,
          FutureOr<InstallmentRepricingDTO?>
        >
    with
        $FutureModifier<InstallmentRepricingDTO?>,
        $FutureProvider<InstallmentRepricingDTO?> {
  InstallmentRepricingProvider._({
    required InstallmentRepricingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentRepricingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentRepricingHash();

  @override
  String toString() {
    return r'installmentRepricingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallmentRepricingDTO?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentRepricingDTO?> create(Ref ref) {
    final argument = this.argument as String;
    return installmentRepricing(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentRepricingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentRepricingHash() =>
    r'5705ec31e02bc5cadcaf5d7219f0fa339176889d';

final class InstallmentRepricingFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InstallmentRepricingDTO?>, String> {
  InstallmentRepricingFamily._()
    : super(
        retry: null,
        name: r'installmentRepricingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentRepricingProvider call(String installmentId) =>
      InstallmentRepricingProvider._(argument: installmentId, from: this);

  @override
  String toString() => r'installmentRepricingProvider';
}

@ProviderFor(installmentInterestAdjustment)
final installmentInterestAdjustmentProvider =
    InstallmentInterestAdjustmentFamily._();

final class InstallmentInterestAdjustmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallmentInterestAdjustmentDTO?>,
          InstallmentInterestAdjustmentDTO?,
          FutureOr<InstallmentInterestAdjustmentDTO?>
        >
    with
        $FutureModifier<InstallmentInterestAdjustmentDTO?>,
        $FutureProvider<InstallmentInterestAdjustmentDTO?> {
  InstallmentInterestAdjustmentProvider._({
    required InstallmentInterestAdjustmentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentInterestAdjustmentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentInterestAdjustmentHash();

  @override
  String toString() {
    return r'installmentInterestAdjustmentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallmentInterestAdjustmentDTO?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentInterestAdjustmentDTO?> create(Ref ref) {
    final argument = this.argument as String;
    return installmentInterestAdjustment(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentInterestAdjustmentProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentInterestAdjustmentHash() =>
    r'9ed227a93cc1138f07a908617e93c2c3926a1c8f';

final class InstallmentInterestAdjustmentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<InstallmentInterestAdjustmentDTO?>,
          String
        > {
  InstallmentInterestAdjustmentFamily._()
    : super(
        retry: null,
        name: r'installmentInterestAdjustmentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentInterestAdjustmentProvider call(String installmentId) =>
      InstallmentInterestAdjustmentProvider._(
        argument: installmentId,
        from: this,
      );

  @override
  String toString() => r'installmentInterestAdjustmentProvider';
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
