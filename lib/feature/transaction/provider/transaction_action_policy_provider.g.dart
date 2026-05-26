// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_action_policy_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 交易详情页据此获取该笔交易适用的 action policy。
///
/// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
/// 这里属于 feature 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
/// 的统一契约，不属于任何业务域；详见 docs/08.2。

@ProviderFor(transactionActionPolicy)
final transactionActionPolicyProvider = TransactionActionPolicyFamily._();

/// 交易详情页据此获取该笔交易适用的 action policy。
///
/// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
/// 这里属于 feature 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
/// 的统一契约，不属于任何业务域；详见 docs/08.2。

final class TransactionActionPolicyProvider
    extends
        $FunctionalProvider<
          TransactionActionPolicy,
          TransactionActionPolicy,
          TransactionActionPolicy
        >
    with $Provider<TransactionActionPolicy> {
  /// 交易详情页据此获取该笔交易适用的 action policy。
  ///
  /// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
  /// 这里属于 feature 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
  /// 的统一契约，不属于任何业务域；详见 docs/08.2。
  TransactionActionPolicyProvider._({
    required TransactionActionPolicyFamily super.from,
    required Transaction super.argument,
  }) : super(
         retry: null,
         name: r'transactionActionPolicyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionActionPolicyHash();

  @override
  String toString() {
    return r'transactionActionPolicyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TransactionActionPolicy> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionActionPolicy create(Ref ref) {
    final argument = this.argument as Transaction;
    return transactionActionPolicy(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionActionPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionActionPolicy>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionActionPolicyProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionActionPolicyHash() =>
    r'84303faa02f9e8f4810e728359d2ce2800ca8e2a';

/// 交易详情页据此获取该笔交易适用的 action policy。
///
/// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
/// 这里属于 feature 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
/// 的统一契约，不属于任何业务域；详见 docs/08.2。

final class TransactionActionPolicyFamily extends $Family
    with $FunctionalFamilyOverride<TransactionActionPolicy, Transaction> {
  TransactionActionPolicyFamily._()
    : super(
        retry: null,
        name: r'transactionActionPolicyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 交易详情页据此获取该笔交易适用的 action policy。
  ///
  /// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
  /// 这里属于 feature 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
  /// 的统一契约，不属于任何业务域；详见 docs/08.2。

  TransactionActionPolicyProvider call(Transaction transaction) =>
      TransactionActionPolicyProvider._(argument: transaction, from: this);

  @override
  String toString() => r'transactionActionPolicyProvider';
}
