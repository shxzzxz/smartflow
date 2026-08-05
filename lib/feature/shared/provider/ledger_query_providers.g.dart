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
        isAutoDispose: false,
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

String _$accountListHash() => r'e2fbceec8eca02ea4b44e45bfa672c5ee444e581';

@ProviderFor(accountGroups)
final accountGroupsProvider = AccountGroupsProvider._();

final class AccountGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountGroup>>,
          List<AccountGroup>,
          Stream<List<AccountGroup>>
        >
    with
        $FutureModifier<List<AccountGroup>>,
        $StreamProvider<List<AccountGroup>> {
  AccountGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountGroupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountGroupsHash();

  @$internal
  @override
  $StreamProviderElement<List<AccountGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AccountGroup>> create(Ref ref) {
    return accountGroups(ref);
  }
}

String _$accountGroupsHash() => r'990dee4dc0a5130a375524d819071432d2e50850';

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
        isAutoDispose: false,
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
    r'7dba339914c95f3ec22cb2f8a1a74347cd07d488';

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
        isAutoDispose: false,
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

String _$accountsByIdHash() => r'd5dd9f6c637be34d228fa06288f65ce2c7dbd9ca';

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
        isAutoDispose: false,
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

String _$accountLookupHash() => r'58ca34461603d4b13ddf7d435acbe6c45cbbb342';

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
         isAutoDispose: false,
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
    r'6bbcecaf03c300be8338b39ff20eee9d5b837558';

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
        isAutoDispose: false,
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
         isAutoDispose: false,
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

String _$categoryTreeHash() => r'8eaaacd2541a9fc1801c6dc0e1a5107b6271b47a';

final class CategoryTreeFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<CategoryNode>>, AccountType> {
  CategoryTreeFamily._()
    : super(
        retry: null,
        name: r'categoryTreeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  CategoryTreeProvider call(AccountType type) =>
      CategoryTreeProvider._(argument: type, from: this);

  @override
  String toString() => r'categoryTreeProvider';
}

@ProviderFor(monthlyBudgetReport)
final monthlyBudgetReportProvider = MonthlyBudgetReportFamily._();

final class MonthlyBudgetReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<MonthlyBudgetReport>,
          MonthlyBudgetReport,
          Stream<MonthlyBudgetReport>
        >
    with
        $FutureModifier<MonthlyBudgetReport>,
        $StreamProvider<MonthlyBudgetReport> {
  MonthlyBudgetReportProvider._({
    required MonthlyBudgetReportFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'monthlyBudgetReportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthlyBudgetReportHash();

  @override
  String toString() {
    return r'monthlyBudgetReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MonthlyBudgetReport> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MonthlyBudgetReport> create(Ref ref) {
    final argument = this.argument as DateTime;
    return monthlyBudgetReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyBudgetReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthlyBudgetReportHash() =>
    r'9474c299c901169c008b4e521fec99f9b8d99ffa';

final class MonthlyBudgetReportFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MonthlyBudgetReport>, DateTime> {
  MonthlyBudgetReportFamily._()
    : super(
        retry: null,
        name: r'monthlyBudgetReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonthlyBudgetReportProvider call(DateTime month) =>
      MonthlyBudgetReportProvider._(argument: month, from: this);

  @override
  String toString() => r'monthlyBudgetReportProvider';
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
    required ({String? settlementAccountId, int limit, int offset})
    super.argument,
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
        this.argument as ({String? settlementAccountId, int limit, int offset});
    return transactionList(
      ref,
      settlementAccountId: argument.settlementAccountId,
      limit: argument.limit,
      offset: argument.offset,
    );
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

String _$transactionListHash() => r'af0c52e107ffd95c5f64285c020c2fd73faa481e';

final class TransactionListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListReadModel>>,
          ({String? settlementAccountId, int limit, int offset})
        > {
  TransactionListFamily._()
    : super(
        retry: null,
        name: r'transactionListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionListProvider call({
    String? settlementAccountId,
    int limit = 50,
    int offset = 0,
  }) => TransactionListProvider._(
    argument: (
      settlementAccountId: settlementAccountId,
      limit: limit,
      offset: offset,
    ),
    from: this,
  );

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
    r'6192570695ceacfa37474f19d3846b8743d6c9c2';

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

String _$netAssetTrendHash() => r'60df911f334c23a62a7c447e52ac27dbb9d98093';

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
