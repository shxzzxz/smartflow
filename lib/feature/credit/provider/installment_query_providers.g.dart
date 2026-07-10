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

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。

@ProviderFor(installmentRepaymentCashflows)
final installmentRepaymentCashflowsProvider =
    InstallmentRepaymentCashflowsFamily._();

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。

final class InstallmentRepaymentCashflowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RepaymentCashflow>>,
          List<RepaymentCashflow>,
          FutureOr<List<RepaymentCashflow>>
        >
    with
        $FutureModifier<List<RepaymentCashflow>>,
        $FutureProvider<List<RepaymentCashflow>> {
  /// 提供 metrics 模块所需的 RepaymentCashflow 列表。
  /// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。
  InstallmentRepaymentCashflowsProvider._({
    required InstallmentRepaymentCashflowsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentRepaymentCashflowsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentRepaymentCashflowsHash();

  @override
  String toString() {
    return r'installmentRepaymentCashflowsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RepaymentCashflow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RepaymentCashflow>> create(Ref ref) {
    final argument = this.argument as String;
    return installmentRepaymentCashflows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstallmentRepaymentCashflowsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentRepaymentCashflowsHash() =>
    r'e326326ded3f51087964ce3612457b0d30fe8b00';

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。

final class InstallmentRepaymentCashflowsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RepaymentCashflow>>, String> {
  InstallmentRepaymentCashflowsFamily._()
    : super(
        retry: null,
        name: r'installmentRepaymentCashflowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 提供 metrics 模块所需的 RepaymentCashflow 列表。
  /// 读取 v2 repayment 聚合；有账务交易时用交易时间，无交易时用记录创建时间。

  InstallmentRepaymentCashflowsProvider call(String contractId) =>
      InstallmentRepaymentCashflowsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentRepaymentCashflowsProvider';
}

/// 按当前合同计划与合同级提前还款计算合同指标。

@ProviderFor(installmentMetrics)
final installmentMetricsProvider = InstallmentMetricsFamily._();

/// 按当前合同计划与合同级提前还款计算合同指标。

final class InstallmentMetricsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContractMetrics>,
          ContractMetrics,
          FutureOr<ContractMetrics>
        >
    with $FutureModifier<ContractMetrics>, $FutureProvider<ContractMetrics> {
  /// 按当前合同计划与合同级提前还款计算合同指标。
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
    r'fb0664c48fa6f9ac35ecfd2c3c77a6aef6956e75';

/// 按当前合同计划与合同级提前还款计算合同指标。

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

  /// 按当前合同计划与合同级提前还款计算合同指标。

  InstallmentMetricsProvider call(String contractId) =>
      InstallmentMetricsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentMetricsProvider';
}
