// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(idGenerator)
final idGeneratorProvider = IdGeneratorProvider._();

final class IdGeneratorProvider
    extends $FunctionalProvider<IdGenerator, IdGenerator, IdGenerator>
    with $Provider<IdGenerator> {
  IdGeneratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idGeneratorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idGeneratorHash();

  @$internal
  @override
  $ProviderElement<IdGenerator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IdGenerator create(Ref ref) {
    return idGenerator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdGenerator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdGenerator>(value),
    );
  }
}

String _$idGeneratorHash() => r'624ed3af1e5159a035175298293b9e8f5b616cd9';

@ProviderFor(systemAccountResolver)
final systemAccountResolverProvider = SystemAccountResolverProvider._();

final class SystemAccountResolverProvider
    extends
        $FunctionalProvider<
          SystemAccountResolver,
          SystemAccountResolver,
          SystemAccountResolver
        >
    with $Provider<SystemAccountResolver> {
  SystemAccountResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemAccountResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemAccountResolverHash();

  @$internal
  @override
  $ProviderElement<SystemAccountResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SystemAccountResolver create(Ref ref) {
    return systemAccountResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemAccountResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemAccountResolver>(value),
    );
  }
}

String _$systemAccountResolverHash() =>
    r'aeb329d1aaf6e2b71728c508c986c02214f78e46';

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

final class AccountRepositoryProvider
    extends
        $FunctionalProvider<
          AccountRepository,
          AccountRepository,
          AccountRepository
        >
    with $Provider<AccountRepository> {
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountRepository create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository>(value),
    );
  }
}

String _$accountRepositoryHash() => r'd18c6b65455a5da1e8787472648c66c231ce9741';

@ProviderFor(accountQueryRepository)
final accountQueryRepositoryProvider = AccountQueryRepositoryProvider._();

final class AccountQueryRepositoryProvider
    extends
        $FunctionalProvider<
          AccountQueryRepository,
          AccountQueryRepository,
          AccountQueryRepository
        >
    with $Provider<AccountQueryRepository> {
  AccountQueryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountQueryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountQueryRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountQueryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountQueryRepository create(Ref ref) {
    return accountQueryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountQueryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountQueryRepository>(value),
    );
  }
}

String _$accountQueryRepositoryHash() =>
    r'082f88ceaf4f0cf0f53a0eac3f6d2d462bc18df8';

@ProviderFor(postingRepository)
final postingRepositoryProvider = PostingRepositoryProvider._();

final class PostingRepositoryProvider
    extends
        $FunctionalProvider<
          PostingRepository,
          PostingRepository,
          PostingRepository
        >
    with $Provider<PostingRepository> {
  PostingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postingRepositoryHash();

  @$internal
  @override
  $ProviderElement<PostingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PostingRepository create(Ref ref) {
    return postingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PostingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PostingRepository>(value),
    );
  }
}

String _$postingRepositoryHash() => r'3f65f8d3cd45f7b9f70f5cb598b6d6e847518ad1';

@ProviderFor(transactionReadRepository)
final transactionReadRepositoryProvider = TransactionReadRepositoryProvider._();

final class TransactionReadRepositoryProvider
    extends
        $FunctionalProvider<
          TransactionReadRepository,
          TransactionReadRepository,
          TransactionReadRepository
        >
    with $Provider<TransactionReadRepository> {
  TransactionReadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionReadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionReadRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionReadRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionReadRepository create(Ref ref) {
    return transactionReadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionReadRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionReadRepository>(value),
    );
  }
}

String _$transactionReadRepositoryHash() =>
    r'6309935e65b9cef7d535b751f6e258921f5ee1cc';

@ProviderFor(entryReadRepository)
final entryReadRepositoryProvider = EntryReadRepositoryProvider._();

final class EntryReadRepositoryProvider
    extends
        $FunctionalProvider<
          EntryReadRepository,
          EntryReadRepository,
          EntryReadRepository
        >
    with $Provider<EntryReadRepository> {
  EntryReadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryReadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryReadRepositoryHash();

  @$internal
  @override
  $ProviderElement<EntryReadRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntryReadRepository create(Ref ref) {
    return entryReadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryReadRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryReadRepository>(value),
    );
  }
}

String _$entryReadRepositoryHash() =>
    r'd442bce4570560b2547b35040221f47281dcb923';

@ProviderFor(transactionDetailReadRepository)
final transactionDetailReadRepositoryProvider =
    TransactionDetailReadRepositoryProvider._();

final class TransactionDetailReadRepositoryProvider
    extends
        $FunctionalProvider<
          TransactionDetailReadRepository,
          TransactionDetailReadRepository,
          TransactionDetailReadRepository
        >
    with $Provider<TransactionDetailReadRepository> {
  TransactionDetailReadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionDetailReadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionDetailReadRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionDetailReadRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionDetailReadRepository create(Ref ref) {
    return transactionDetailReadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionDetailReadRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionDetailReadRepository>(
        value,
      ),
    );
  }
}

String _$transactionDetailReadRepositoryHash() =>
    r'da8e89f2b6c9563e8f6d4440db8bc7bc2fdd0d26';

@ProviderFor(balanceAggregateRepository)
final balanceAggregateRepositoryProvider =
    BalanceAggregateRepositoryProvider._();

final class BalanceAggregateRepositoryProvider
    extends
        $FunctionalProvider<
          BalanceAggregateRepository,
          BalanceAggregateRepository,
          BalanceAggregateRepository
        >
    with $Provider<BalanceAggregateRepository> {
  BalanceAggregateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'balanceAggregateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$balanceAggregateRepositoryHash();

  @$internal
  @override
  $ProviderElement<BalanceAggregateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BalanceAggregateRepository create(Ref ref) {
    return balanceAggregateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BalanceAggregateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BalanceAggregateRepository>(value),
    );
  }
}

String _$balanceAggregateRepositoryHash() =>
    r'7aacd32ea77456968cf7c23dedc0c7a4503328ee';

@ProviderFor(transactionRunner)
final transactionRunnerProvider = TransactionRunnerProvider._();

final class TransactionRunnerProvider
    extends
        $FunctionalProvider<
          TransactionRunner,
          TransactionRunner,
          TransactionRunner
        >
    with $Provider<TransactionRunner> {
  TransactionRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionRunnerHash();

  @$internal
  @override
  $ProviderElement<TransactionRunner> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionRunner create(Ref ref) {
    return transactionRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionRunner>(value),
    );
  }
}

String _$transactionRunnerHash() => r'ac2e79f7455255f3338788cfe57587c4e97b9fe4';

@ProviderFor(updateChannelStore)
final updateChannelStoreProvider = UpdateChannelStoreProvider._();

final class UpdateChannelStoreProvider
    extends
        $FunctionalProvider<
          UpdateChannelStore,
          UpdateChannelStore,
          UpdateChannelStore
        >
    with $Provider<UpdateChannelStore> {
  UpdateChannelStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateChannelStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateChannelStoreHash();

  @$internal
  @override
  $ProviderElement<UpdateChannelStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateChannelStore create(Ref ref) {
    return updateChannelStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateChannelStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateChannelStore>(value),
    );
  }
}

String _$updateChannelStoreHash() =>
    r'c796ea2e6828c56f68155adc5f4f8ea1e59de7be';

@ProviderFor(accountAppService)
final accountAppServiceProvider = AccountAppServiceProvider._();

final class AccountAppServiceProvider
    extends
        $FunctionalProvider<
          AccountAppService,
          AccountAppService,
          AccountAppService
        >
    with $Provider<AccountAppService> {
  AccountAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountAppServiceHash();

  @$internal
  @override
  $ProviderElement<AccountAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountAppService create(Ref ref) {
    return accountAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountAppService>(value),
    );
  }
}

String _$accountAppServiceHash() => r'b1b6c8c5b13ba58e9227e25468e7aae8efbae974';

@ProviderFor(categoryService)
final categoryServiceProvider = CategoryServiceProvider._();

final class CategoryServiceProvider
    extends
        $FunctionalProvider<CategoryService, CategoryService, CategoryService>
    with $Provider<CategoryService> {
  CategoryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryServiceHash();

  @$internal
  @override
  $ProviderElement<CategoryService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoryService create(Ref ref) {
    return categoryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryService>(value),
    );
  }
}

String _$categoryServiceHash() => r'2c968f340b7b19b9547e97677a4b8a9095a9379c';

@ProviderFor(postingAppService)
final postingAppServiceProvider = PostingAppServiceProvider._();

final class PostingAppServiceProvider
    extends
        $FunctionalProvider<
          PostingAppService,
          PostingAppService,
          PostingAppService
        >
    with $Provider<PostingAppService> {
  PostingAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postingAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postingAppServiceHash();

  @$internal
  @override
  $ProviderElement<PostingAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PostingAppService create(Ref ref) {
    return postingAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PostingAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PostingAppService>(value),
    );
  }
}

String _$postingAppServiceHash() => r'96b816a89b16b859a59d654bab948b9863970d1c';

@ProviderFor(transactionQueryService)
final transactionQueryServiceProvider = TransactionQueryServiceProvider._();

final class TransactionQueryServiceProvider
    extends
        $FunctionalProvider<
          TransactionQueryService,
          TransactionQueryService,
          TransactionQueryService
        >
    with $Provider<TransactionQueryService> {
  TransactionQueryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionQueryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionQueryServiceHash();

  @$internal
  @override
  $ProviderElement<TransactionQueryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionQueryService create(Ref ref) {
    return transactionQueryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionQueryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionQueryService>(value),
    );
  }
}

String _$transactionQueryServiceHash() =>
    r'7981586a24055b84ce8a126a4c9369ad7142d1c1';

@ProviderFor(financialMetricsService)
final financialMetricsServiceProvider = FinancialMetricsServiceProvider._();

final class FinancialMetricsServiceProvider
    extends
        $FunctionalProvider<
          FinancialMetricsService,
          FinancialMetricsService,
          FinancialMetricsService
        >
    with $Provider<FinancialMetricsService> {
  FinancialMetricsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financialMetricsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financialMetricsServiceHash();

  @$internal
  @override
  $ProviderElement<FinancialMetricsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinancialMetricsService create(Ref ref) {
    return financialMetricsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinancialMetricsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinancialMetricsService>(value),
    );
  }
}

String _$financialMetricsServiceHash() =>
    r'7482e97011511fa5fb010f3190c1f715dfc14acc';

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

String _$accountListHash() => r'607894e78c7d34e5abdc3cb0395745090caf5fea';

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 用法:在 widget 内 `ref.watch(accountsByIdProvider).value ?? const {}`,
/// 配合 `widget/business/account_lookup.dart` 的 extension 使用。

@ProviderFor(accountsById)
final accountsByIdProvider = AccountsByIdProvider._();

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 用法:在 widget 内 `ref.watch(accountsByIdProvider).value ?? const {}`,
/// 配合 `widget/business/account_lookup.dart` 的 extension 使用。

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
  /// 用法:在 widget 内 `ref.watch(accountsByIdProvider).value ?? const {}`,
  /// 配合 `widget/business/account_lookup.dart` 的 extension 使用。
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

String _$accountsByIdHash() => r'aa7c27bbe42037123523871ea8dadbf089865b46';

@ProviderFor(accountsForUsage)
final accountsForUsageProvider = AccountsForUsageFamily._();

final class AccountsForUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  AccountsForUsageProvider._({
    required AccountsForUsageFamily super.from,
    required AccountUsage super.argument,
  }) : super(
         retry: null,
         name: r'accountsForUsageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountsForUsageHash();

  @override
  String toString() {
    return r'accountsForUsageProvider'
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
    final argument = this.argument as AccountUsage;
    return accountsForUsage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountsForUsageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountsForUsageHash() => r'9b12a137c3aa376fd54c40f02787f8ad98483f21';

final class AccountsForUsageFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Account>>, AccountUsage> {
  AccountsForUsageFamily._()
    : super(
        retry: null,
        name: r'accountsForUsageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountsForUsageProvider call(AccountUsage usage) =>
      AccountsForUsageProvider._(argument: usage, from: this);

  @override
  String toString() => r'accountsForUsageProvider';
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

String _$accountsByTypesHash() => r'eac9711c59b70bdc3742b1ad5073b4bd1498e158';

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

String _$categoryTreeHash() => r'b36933c3f92afd9f64032f635700417c63b68347';

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
          AsyncValue<List<TransactionListItem>>,
          List<TransactionListItem>,
          Stream<List<TransactionListItem>>
        >
    with
        $FutureModifier<List<TransactionListItem>>,
        $StreamProvider<List<TransactionListItem>> {
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
  $StreamProviderElement<List<TransactionListItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TransactionListItem>> create(Ref ref) {
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

String _$transactionListHash() => r'eb89425a5fdc8ae3b1f66699bd1586aa17f9019f';

final class TransactionListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TransactionListItem>>, String?> {
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

@ProviderFor(homeMonthTransactions)
final homeMonthTransactionsProvider = HomeMonthTransactionsFamily._();

final class HomeMonthTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionListItem>>,
          List<TransactionListItem>,
          Stream<List<TransactionListItem>>
        >
    with
        $FutureModifier<List<TransactionListItem>>,
        $StreamProvider<List<TransactionListItem>> {
  HomeMonthTransactionsProvider._({
    required HomeMonthTransactionsFamily super.from,
    required ({int year, int month}) super.argument,
  }) : super(
         retry: null,
         name: r'homeMonthTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeMonthTransactionsHash();

  @override
  String toString() {
    return r'homeMonthTransactionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<TransactionListItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TransactionListItem>> create(Ref ref) {
    final argument = this.argument as ({int year, int month});
    return homeMonthTransactions(
      ref,
      year: argument.year,
      month: argument.month,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeMonthTransactionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeMonthTransactionsHash() =>
    r'12e39d210f7388150bcf69d9a46e7f8f8820628b';

final class HomeMonthTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TransactionListItem>>,
          ({int year, int month})
        > {
  HomeMonthTransactionsFamily._()
    : super(
        retry: null,
        name: r'homeMonthTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeMonthTransactionsProvider call({required int year, required int month}) =>
      HomeMonthTransactionsProvider._(
        argument: (year: year, month: month),
        from: this,
      );

  @override
  String toString() => r'homeMonthTransactionsProvider';
}

@ProviderFor(homeMonthCashflowComparison)
final homeMonthCashflowComparisonProvider =
    HomeMonthCashflowComparisonFamily._();

final class HomeMonthCashflowComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<CashflowComparison>,
          CashflowComparison,
          Stream<CashflowComparison>
        >
    with
        $FutureModifier<CashflowComparison>,
        $StreamProvider<CashflowComparison> {
  HomeMonthCashflowComparisonProvider._({
    required HomeMonthCashflowComparisonFamily super.from,
    required ({int year, int month}) super.argument,
  }) : super(
         retry: null,
         name: r'homeMonthCashflowComparisonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeMonthCashflowComparisonHash();

  @override
  String toString() {
    return r'homeMonthCashflowComparisonProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<CashflowComparison> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CashflowComparison> create(Ref ref) {
    final argument = this.argument as ({int year, int month});
    return homeMonthCashflowComparison(
      ref,
      year: argument.year,
      month: argument.month,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeMonthCashflowComparisonProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeMonthCashflowComparisonHash() =>
    r'a28e1a5675e98d8b94361ccdb4cfba73bca464e3';

final class HomeMonthCashflowComparisonFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<CashflowComparison>,
          ({int year, int month})
        > {
  HomeMonthCashflowComparisonFamily._()
    : super(
        retry: null,
        name: r'homeMonthCashflowComparisonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeMonthCashflowComparisonProvider call({
    required int year,
    required int month,
  }) => HomeMonthCashflowComparisonProvider._(
    argument: (year: year, month: month),
    from: this,
  );

  @override
  String toString() => r'homeMonthCashflowComparisonProvider';
}

@ProviderFor(homeMonthDailyCashflowSummaries)
final homeMonthDailyCashflowSummariesProvider =
    HomeMonthDailyCashflowSummariesFamily._();

final class HomeMonthDailyCashflowSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyCashflowSummary>>,
          List<DailyCashflowSummary>,
          Stream<List<DailyCashflowSummary>>
        >
    with
        $FutureModifier<List<DailyCashflowSummary>>,
        $StreamProvider<List<DailyCashflowSummary>> {
  HomeMonthDailyCashflowSummariesProvider._({
    required HomeMonthDailyCashflowSummariesFamily super.from,
    required ({int year, int month}) super.argument,
  }) : super(
         retry: null,
         name: r'homeMonthDailyCashflowSummariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeMonthDailyCashflowSummariesHash();

  @override
  String toString() {
    return r'homeMonthDailyCashflowSummariesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<DailyCashflowSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DailyCashflowSummary>> create(Ref ref) {
    final argument = this.argument as ({int year, int month});
    return homeMonthDailyCashflowSummaries(
      ref,
      year: argument.year,
      month: argument.month,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeMonthDailyCashflowSummariesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeMonthDailyCashflowSummariesHash() =>
    r'065be5249de795011c3f489e3fc99147758ccfb2';

final class HomeMonthDailyCashflowSummariesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<DailyCashflowSummary>>,
          ({int year, int month})
        > {
  HomeMonthDailyCashflowSummariesFamily._()
    : super(
        retry: null,
        name: r'homeMonthDailyCashflowSummariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeMonthDailyCashflowSummariesProvider call({
    required int year,
    required int month,
  }) => HomeMonthDailyCashflowSummariesProvider._(
    argument: (year: year, month: month),
    from: this,
  );

  @override
  String toString() => r'homeMonthDailyCashflowSummariesProvider';
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

@ProviderFor(installmentRepository)
final installmentRepositoryProvider = InstallmentRepositoryProvider._();

final class InstallmentRepositoryProvider
    extends
        $FunctionalProvider<
          InstallmentRepository,
          InstallmentRepository,
          InstallmentRepository
        >
    with $Provider<InstallmentRepository> {
  InstallmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<InstallmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallmentRepository create(Ref ref) {
    return installmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallmentRepository>(value),
    );
  }
}

String _$installmentRepositoryHash() =>
    r'a17d0d3d58072d354187bd162ed9185ff15f88bb';

@ProviderFor(installmentService)
final installmentServiceProvider = InstallmentServiceProvider._();

final class InstallmentServiceProvider
    extends
        $FunctionalProvider<
          InstallmentService,
          InstallmentService,
          InstallmentService
        >
    with $Provider<InstallmentService> {
  InstallmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installmentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installmentServiceHash();

  @$internal
  @override
  $ProviderElement<InstallmentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallmentService create(Ref ref) {
    return installmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallmentService>(value),
    );
  }
}

String _$installmentServiceHash() =>
    r'673394643f3a100ebde703471977ff651cf18155';

@ProviderFor(creditService)
final creditServiceProvider = CreditServiceProvider._();

final class CreditServiceProvider
    extends $FunctionalProvider<CreditService, CreditService, CreditService>
    with $Provider<CreditService> {
  CreditServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditServiceHash();

  @$internal
  @override
  $ProviderElement<CreditService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreditService create(Ref ref) {
    return creditService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreditService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreditService>(value),
    );
  }
}

String _$creditServiceHash() => r'294ea4dba42503b4d6e995ca9d73cfac3c18b6e6';

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
    r'3afe718039fe3e6c6fabc854b1884c2da11fdea0';

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
    r'd039b7b60391cd2d58638a6c1bd0d333d88926ee';

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
    r'61f83193fc39e7008f1b3def2e73063fc880c724';

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
    r'a57cbb38a572a6afccd7ef44c150d12c862a508c';

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
    r'189dd4b95f0f40ff4c340ea729b443e2add79603';

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
