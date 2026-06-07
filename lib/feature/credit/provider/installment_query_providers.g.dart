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
          AsyncValue<List<InstallmentRepayment>>,
          List<InstallmentRepayment>,
          FutureOr<List<InstallmentRepayment>>
        >
    with
        $FutureModifier<List<InstallmentRepayment>>,
        $FutureProvider<List<InstallmentRepayment>> {
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
  $FutureProviderElement<List<InstallmentRepayment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstallmentRepayment>> create(Ref ref) {
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
    r'8b2f9717d36c308e76f2df38ae155b75386a10d4';

final class InstallmentRepaymentsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<InstallmentRepayment>>,
          String
        > {
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

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。

@ProviderFor(installmentRepaymentCashflows)
final installmentRepaymentCashflowsProvider =
    InstallmentRepaymentCashflowsFamily._();

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。

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
  /// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。
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
    r'787633331214432ed6430e64103971c39fcb6fc0';

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。

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
  /// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。

  InstallmentRepaymentCashflowsProvider call(String contractId) =>
      InstallmentRepaymentCashflowsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentRepaymentCashflowsProvider';
}

/// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。

@ProviderFor(installmentMetrics)
final installmentMetricsProvider = InstallmentMetricsFamily._();

/// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。

final class InstallmentMetricsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({ContractMetrics actual, ContractMetrics designed})>,
          ({ContractMetrics actual, ContractMetrics designed}),
          FutureOr<({ContractMetrics actual, ContractMetrics designed})>
        >
    with
        $FutureModifier<({ContractMetrics actual, ContractMetrics designed})>,
        $FutureProvider<({ContractMetrics actual, ContractMetrics designed})> {
  /// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。
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
  $FutureProviderElement<({ContractMetrics actual, ContractMetrics designed})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({ContractMetrics actual, ContractMetrics designed})> create(
    Ref ref,
  ) {
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
    r'48808f61bd5fe5d4386bf8fe50e2335fd8c557a7';

/// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。

final class InstallmentMetricsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({ContractMetrics actual, ContractMetrics designed})>,
          String
        > {
  InstallmentMetricsFamily._()
    : super(
        retry: null,
        name: r'installmentMetricsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。

  InstallmentMetricsProvider call(String contractId) =>
      InstallmentMetricsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'installmentMetricsProvider';
}
