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
          AsyncValue<List<InstallmentContract>>,
          List<InstallmentContract>,
          FutureOr<List<InstallmentContract>>
        >
    with
        $FutureModifier<List<InstallmentContract>>,
        $FutureProvider<List<InstallmentContract>> {
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
  $FutureProviderElement<List<InstallmentContract>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentContract>> create(Ref ref) {
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
    r'301be457f6f3552f9a43c09c3d854720f8a87aa1';

final class InstallmentContractsByAccountFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<InstallmentContract>>, String> {
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
          AsyncValue<InstallmentContract?>,
          InstallmentContract?,
          FutureOr<InstallmentContract?>
        >
    with
        $FutureModifier<InstallmentContract?>,
        $FutureProvider<InstallmentContract?> {
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
  $FutureProviderElement<InstallmentContract?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallmentContract?> create(Ref ref) {
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
    r'30a399371482ebfe566ce3d4e46a0ff5981a7a77';

final class InstallmentContractFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InstallmentContract?>, String> {
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
          AsyncValue<List<InstallmentSchedule>>,
          List<InstallmentSchedule>,
          FutureOr<List<InstallmentSchedule>>
        >
    with
        $FutureModifier<List<InstallmentSchedule>>,
        $FutureProvider<List<InstallmentSchedule>> {
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
  $FutureProviderElement<List<InstallmentSchedule>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentSchedule>> create(Ref ref) {
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
    r'a331b0b83f6b3b4caa3da5de0cc88ae302b19fc1';

final class InstallmentSchedulesFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<InstallmentSchedule>>, String> {
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

@ProviderFor(installmentRepayments)
final installmentRepaymentsProvider = InstallmentRepaymentsFamily._();

final class InstallmentRepaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContractRepayment>>,
          List<ContractRepayment>,
          FutureOr<List<ContractRepayment>>
        >
    with
        $FutureModifier<List<ContractRepayment>>,
        $FutureProvider<List<ContractRepayment>> {
  InstallmentRepaymentsProvider._({
    required InstallmentRepaymentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentRepaymentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentRepaymentsHash();

  @override
  String toString() {
    return r'installmentRepaymentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContractRepayment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContractRepayment>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentRepayments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentRepaymentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentRepaymentsHash() =>
    r'b25d0143eb2aeb9bcca611110b1bdbf79aa9272e';

final class InstallmentRepaymentsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContractRepayment>>, String> {
  InstallmentRepaymentsFamily._()
    : super(
        retry: null,
        name: r'installmentRepaymentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentRepaymentsProvider call(String contractId) =>
      InstallmentRepaymentsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentRepaymentsProvider';
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
