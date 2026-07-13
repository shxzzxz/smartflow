// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountList)
final accountListProvider = AccountListProvider._();

final class AccountListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  AccountListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountListHash();

  @$internal
  @override
  $StreamProviderElement<List<Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Account>> create(Ref ref) {
    return accountList(ref);
  }
}

String _$accountListHash() => r'95dee3110f192c62457e962aca9bdbefc29c02c6';

@ProviderFor(creditLiabilityAccountsByAccountId)
final creditLiabilityAccountsByAccountIdProvider =
    CreditLiabilityAccountsByAccountIdProvider._();

final class CreditLiabilityAccountsByAccountIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, CreditLiabilityAccountReadModel>>,
          Map<String, CreditLiabilityAccountReadModel>,
          Stream<Map<String, CreditLiabilityAccountReadModel>>
        >
    with
        $FutureModifier<Map<String, CreditLiabilityAccountReadModel>>,
        $StreamProvider<Map<String, CreditLiabilityAccountReadModel>> {
  CreditLiabilityAccountsByAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditLiabilityAccountsByAccountIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$creditLiabilityAccountsByAccountIdHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, CreditLiabilityAccountReadModel>>
  $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, CreditLiabilityAccountReadModel>> create(Ref ref) {
    return creditLiabilityAccountsByAccountId(ref);
  }
}

String _$creditLiabilityAccountsByAccountIdHash() =>
    r'7e960b02eaade95eef2f46ca54d41c73a64cfc84';

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 新 UI 优先使用 `accountLookupProvider`; 仍保留 Map 形式给表单解析等旧路径使用。

@ProviderFor(accountsById)
final accountsByIdProvider = AccountsByIdProvider._();

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 新 UI 优先使用 `accountLookupProvider`; 仍保留 Map 形式给表单解析等旧路径使用。

final class AccountsByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Account>>,
          Map<String, Account>,
          Stream<Map<String, Account>>
        >
    with
        $FutureModifier<Map<String, Account>>,
        $StreamProvider<Map<String, Account>> {
  /// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
  /// 解析为 Account 元数据(type / name / iconKey 等)。
  ///
  /// 新 UI 优先使用 `accountLookupProvider`; 仍保留 Map 形式给表单解析等旧路径使用。
  AccountsByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountsByIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountsByIdHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, Account>> create(Ref ref) {
    return accountsById(ref);
  }
}

String _$accountsByIdHash() => r'0c0c7d4fc91a4f029ff3081a98c2a9d98b31ff20';

@ProviderFor(accountLookup)
final accountLookupProvider = AccountLookupProvider._();

final class AccountLookupProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountLookup>,
          AccountLookup,
          Stream<AccountLookup>
        >
    with $FutureModifier<AccountLookup>, $StreamProvider<AccountLookup> {
  AccountLookupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountLookupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountLookupHash();

  @$internal
  @override
  $StreamProviderElement<AccountLookup> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AccountLookup> create(Ref ref) {
    return accountLookup(ref);
  }
}

String _$accountLookupHash() => r'1e7f3ff1a838b081749c675acdf5c4be8a9f8505';

@ProviderFor(accountsForSelectionPurpose)
final accountsForSelectionPurposeProvider =
    AccountsForSelectionPurposeFamily._();

final class AccountsForSelectionPurposeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  AccountsForSelectionPurposeProvider._({
    required AccountsForSelectionPurposeFamily super.from,
    required AccountSelectionPurpose super.argument,
  }) : super(
         retry: null,
         name: r'accountsForSelectionPurposeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountsForSelectionPurposeHash();

  @override
  String toString() {
    return r'accountsForSelectionPurposeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Account>> create(Ref ref) {
    final argument = this.argument as AccountSelectionPurpose;
    return accountsForSelectionPurpose(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountsForSelectionPurposeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountsForSelectionPurposeHash() =>
    r'3425b75f9f7150f6f28fe1c0867a1f5e3af5cd04';

final class AccountsForSelectionPurposeFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<Account>>,
          AccountSelectionPurpose
        > {
  AccountsForSelectionPurposeFamily._()
    : super(
        retry: null,
        name: r'accountsForSelectionPurposeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountsForSelectionPurposeProvider call(AccountSelectionPurpose purpose) =>
      AccountsForSelectionPurposeProvider._(argument: purpose, from: this);

  @override
  String toString() => r'accountsForSelectionPurposeProvider';
}

@ProviderFor(accountsByTypes)
final accountsByTypesProvider = AccountsByTypesFamily._();

final class AccountsByTypesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  AccountsByTypesProvider._({
    required AccountsByTypesFamily super.from,
    required Set<AccountType> super.argument,
  }) : super(
         retry: null,
         name: r'accountsByTypesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountsByTypesHash();

  @override
  String toString() {
    return r'accountsByTypesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Account>> create(Ref ref) {
    final argument = this.argument as Set<AccountType>;
    return accountsByTypes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountsByTypesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountsByTypesHash() => r'8484a3d8415250b3d610c912fbacb0bc00f94d38';

final class AccountsByTypesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Account>>, Set<AccountType>> {
  AccountsByTypesFamily._()
    : super(
        retry: null,
        name: r'accountsByTypesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountsByTypesProvider call(Set<AccountType> types) =>
      AccountsByTypesProvider._(argument: types, from: this);

  @override
  String toString() => r'accountsByTypesProvider';
}

@ProviderFor(categoryTree)
final categoryTreeProvider = CategoryTreeFamily._();

final class CategoryTreeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoryNode>>,
          List<CategoryNode>,
          Stream<List<CategoryNode>>
        >
    with
        $FutureModifier<List<CategoryNode>>,
        $StreamProvider<List<CategoryNode>> {
  CategoryTreeProvider._({
    required CategoryTreeFamily super.from,
    required AccountType super.argument,
  }) : super(
         retry: null,
         name: r'categoryTreeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryTreeHash();

  @override
  String toString() {
    return r'categoryTreeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<CategoryNode>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CategoryNode>> create(Ref ref) {
    final argument = this.argument as AccountType;
    return categoryTree(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryTreeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryTreeHash() => r'7723f395e8ee6c05549c642617b4f3724b160242';

final class CategoryTreeFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<CategoryNode>>, AccountType> {
  CategoryTreeFamily._()
    : super(
        retry: null,
        name: r'categoryTreeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CategoryTreeProvider call(AccountType type) =>
      CategoryTreeProvider._(argument: type, from: this);

  @override
  String toString() => r'categoryTreeProvider';
}

@ProviderFor(transactionList)
final transactionListProvider = TransactionListFamily._();

final class TransactionListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListReadModel>>,
          List<TransactionListReadModel>,
          Stream<List<TransactionListReadModel>>
        >
    with
        $FutureModifier<List<TransactionListReadModel>>,
        $StreamProvider<List<TransactionListReadModel>> {
  TransactionListProvider._({
    required TransactionListFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'transactionListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionListHash();

  @override
  String toString() {
    return r'transactionListProvider'
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
    final argument = this.argument as String?;
    return transactionList(ref, accountId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionListHash() => r'5d311170c35eb08026988b1d846b7ebe0013db0b';

final class TransactionListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          String?
        > {
  TransactionListFamily._()
    : super(
        retry: null,
        name: r'transactionListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionListProvider call({String? accountId}) =>
      TransactionListProvider._(argument: accountId, from: this);

  @override
  String toString() => r'transactionListProvider';
}

@ProviderFor(balanceSheetComparison)
final balanceSheetComparisonProvider = BalanceSheetComparisonProvider._();

final class BalanceSheetComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<BalanceSheetComparison>,
          BalanceSheetComparison,
          Stream<BalanceSheetComparison>
        >
    with
        $FutureModifier<BalanceSheetComparison>,
        $StreamProvider<BalanceSheetComparison> {
  BalanceSheetComparisonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'balanceSheetComparisonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$balanceSheetComparisonHash();

  @$internal
  @override
  $StreamProviderElement<BalanceSheetComparison> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BalanceSheetComparison> create(Ref ref) {
    return balanceSheetComparison(ref);
  }
}

String _$balanceSheetComparisonHash() =>
    r'3074d4a48f31dc81aabfc69f6d6645cf53838e18';

@ProviderFor(netAssetTrend)
final netAssetTrendProvider = NetAssetTrendFamily._();

final class NetAssetTrendProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NetAssetTrendPoint>>,
          List<NetAssetTrendPoint>,
          Stream<List<NetAssetTrendPoint>>
        >
    with
        $FutureModifier<List<NetAssetTrendPoint>>,
        $StreamProvider<List<NetAssetTrendPoint>> {
  NetAssetTrendProvider._({
    required NetAssetTrendFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'netAssetTrendProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$netAssetTrendHash();

  @override
  String toString() {
    return r'netAssetTrendProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<NetAssetTrendPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NetAssetTrendPoint>> create(Ref ref) {
    final argument = this.argument as int;
    return netAssetTrend(ref, months: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NetAssetTrendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$netAssetTrendHash() => r'02f663fc1ea286e5ee9a693a7a32a5610a1aa41d';

final class NetAssetTrendFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<NetAssetTrendPoint>>, int> {
  NetAssetTrendFamily._()
    : super(
        retry: null,
        name: r'netAssetTrendProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NetAssetTrendProvider call({int months = 6}) =>
      NetAssetTrendProvider._(argument: months, from: this);

  @override
  String toString() => r'netAssetTrendProvider';
}

@ProviderFor(transactionDetail)
final transactionDetailProvider = TransactionDetailFamily._();

final class TransactionDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<TransactionDetail?>,
          TransactionDetail?,
          Stream<TransactionDetail?>
        >
    with
        $FutureModifier<TransactionDetail?>,
        $StreamProvider<TransactionDetail?> {
  TransactionDetailProvider._({
    required TransactionDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transactionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionDetailHash();

  @override
  String toString() {
    return r'transactionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TransactionDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TransactionDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return transactionDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionDetailHash() => r'c6b06c2af1c8312d6717f557cc52bb646d9a6c21';

final class TransactionDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TransactionDetail?>, String> {
  TransactionDetailFamily._()
    : super(
        retry: null,
        name: r'transactionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionDetailProvider call(String transactionId) =>
      TransactionDetailProvider._(argument: transactionId, from: this);

  @override
  String toString() => r'transactionDetailProvider';
}
