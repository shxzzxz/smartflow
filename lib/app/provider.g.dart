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
    r'579e101d67d3ba95065c2b6e897df1dd830f311f';

@ProviderFor(accountQueryService)
final accountQueryServiceProvider = AccountQueryServiceProvider._();

final class AccountQueryServiceProvider
    extends
        $FunctionalProvider<
          AccountQueryService,
          AccountQueryService,
          AccountQueryService
        >
    with $Provider<AccountQueryService> {
  AccountQueryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountQueryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountQueryServiceHash();

  @$internal
  @override
  $ProviderElement<AccountQueryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountQueryService create(Ref ref) {
    return accountQueryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountQueryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountQueryService>(value),
    );
  }
}

String _$accountQueryServiceHash() =>
    r'906e4ed354b09e6f55d4ad7c2c08e5f3418a7fb3';

@ProviderFor(ledgerRepository)
final ledgerRepositoryProvider = LedgerRepositoryProvider._();

final class LedgerRepositoryProvider
    extends
        $FunctionalProvider<
          DriftPostingRepository,
          DriftPostingRepository,
          DriftPostingRepository
        >
    with $Provider<DriftPostingRepository> {
  LedgerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerRepositoryHash();

  @$internal
  @override
  $ProviderElement<DriftPostingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DriftPostingRepository create(Ref ref) {
    return ledgerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriftPostingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriftPostingRepository>(value),
    );
  }
}

String _$ledgerRepositoryHash() => r'18965b95482a5f4fe039ea90243451edea89725d';

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

String _$accountAppServiceHash() => r'bf58132d9e6d968383bc026f0f7c4aa60a349efa';

@ProviderFor(categoryAppService)
final categoryAppServiceProvider = CategoryAppServiceProvider._();

final class CategoryAppServiceProvider
    extends
        $FunctionalProvider<
          CategoryAppService,
          CategoryAppService,
          CategoryAppService
        >
    with $Provider<CategoryAppService> {
  CategoryAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryAppServiceHash();

  @$internal
  @override
  $ProviderElement<CategoryAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryAppService create(Ref ref) {
    return categoryAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryAppService>(value),
    );
  }
}

String _$categoryAppServiceHash() =>
    r'8276e832859893662b833bd9d014f0abe5a70dda';

@ProviderFor(categoryQueryService)
final categoryQueryServiceProvider = CategoryQueryServiceProvider._();

final class CategoryQueryServiceProvider
    extends
        $FunctionalProvider<
          CategoryQueryService,
          CategoryQueryService,
          CategoryQueryService
        >
    with $Provider<CategoryQueryService> {
  CategoryQueryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryQueryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryQueryServiceHash();

  @$internal
  @override
  $ProviderElement<CategoryQueryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryQueryService create(Ref ref) {
    return categoryQueryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryQueryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryQueryService>(value),
    );
  }
}

String _$categoryQueryServiceHash() =>
    r'357385357c2569a955070fc7261982084e868dc4';

@ProviderFor(transactionLedgerWriter)
final transactionLedgerWriterProvider = TransactionLedgerWriterProvider._();

final class TransactionLedgerWriterProvider
    extends
        $FunctionalProvider<
          TransactionLedgerWriter,
          TransactionLedgerWriter,
          TransactionLedgerWriter
        >
    with $Provider<TransactionLedgerWriter> {
  TransactionLedgerWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionLedgerWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionLedgerWriterHash();

  @$internal
  @override
  $ProviderElement<TransactionLedgerWriter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionLedgerWriter create(Ref ref) {
    return transactionLedgerWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionLedgerWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionLedgerWriter>(value),
    );
  }
}

String _$transactionLedgerWriterHash() =>
    r'113e9d83d6fc721e66f7fdd7032288d0de8cc853';

@ProviderFor(ledgerPostingService)
final ledgerPostingServiceProvider = LedgerPostingServiceProvider._();

final class LedgerPostingServiceProvider
    extends
        $FunctionalProvider<
          LedgerPostingService,
          LedgerPostingService,
          LedgerPostingService
        >
    with $Provider<LedgerPostingService> {
  LedgerPostingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerPostingServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerPostingServiceHash();

  @$internal
  @override
  $ProviderElement<LedgerPostingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LedgerPostingService create(Ref ref) {
    return ledgerPostingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedgerPostingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedgerPostingService>(value),
    );
  }
}

String _$ledgerPostingServiceHash() =>
    r'c8bec6c762dbe8f90f901aacb95e54b6ad57fb39';

@ProviderFor(transactionPostingAppService)
final transactionPostingAppServiceProvider =
    TransactionPostingAppServiceProvider._();

final class TransactionPostingAppServiceProvider
    extends
        $FunctionalProvider<
          TransactionPostingAppService,
          TransactionPostingAppService,
          TransactionPostingAppService
        >
    with $Provider<TransactionPostingAppService> {
  TransactionPostingAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionPostingAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionPostingAppServiceHash();

  @$internal
  @override
  $ProviderElement<TransactionPostingAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionPostingAppService create(Ref ref) {
    return transactionPostingAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionPostingAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionPostingAppService>(value),
    );
  }
}

String _$transactionPostingAppServiceHash() =>
    r'373f71c813c0b0500e1b0cd6d1ec64b38f45cc11';

@ProviderFor(transactionCorrectionAppService)
final transactionCorrectionAppServiceProvider =
    TransactionCorrectionAppServiceProvider._();

final class TransactionCorrectionAppServiceProvider
    extends
        $FunctionalProvider<
          TransactionCorrectionAppService,
          TransactionCorrectionAppService,
          TransactionCorrectionAppService
        >
    with $Provider<TransactionCorrectionAppService> {
  TransactionCorrectionAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionCorrectionAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionCorrectionAppServiceHash();

  @$internal
  @override
  $ProviderElement<TransactionCorrectionAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionCorrectionAppService create(Ref ref) {
    return transactionCorrectionAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionCorrectionAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionCorrectionAppService>(
        value,
      ),
    );
  }
}

String _$transactionCorrectionAppServiceHash() =>
    r'f84d743254b88057ce8c4d95508f59f759c9eeb4';

@ProviderFor(transactionUpdateAppService)
final transactionUpdateAppServiceProvider =
    TransactionUpdateAppServiceProvider._();

final class TransactionUpdateAppServiceProvider
    extends
        $FunctionalProvider<
          TransactionUpdateAppService,
          TransactionUpdateAppService,
          TransactionUpdateAppService
        >
    with $Provider<TransactionUpdateAppService> {
  TransactionUpdateAppServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionUpdateAppServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionUpdateAppServiceHash();

  @$internal
  @override
  $ProviderElement<TransactionUpdateAppService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionUpdateAppService create(Ref ref) {
    return transactionUpdateAppService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionUpdateAppService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionUpdateAppService>(value),
    );
  }
}

String _$transactionUpdateAppServiceHash() =>
    r'bcd801d84c5097c8e448b6bc6bbd3ff84c822c9a';

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
    r'a38d25a9a53a3527bf7bc3d0fbd0c193e77c2f4d';

@ProviderFor(installmentQueryService)
final installmentQueryServiceProvider = InstallmentQueryServiceProvider._();

final class InstallmentQueryServiceProvider
    extends
        $FunctionalProvider<
          InstallmentQueryService,
          InstallmentQueryService,
          InstallmentQueryService
        >
    with $Provider<InstallmentQueryService> {
  InstallmentQueryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installmentQueryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installmentQueryServiceHash();

  @$internal
  @override
  $ProviderElement<InstallmentQueryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallmentQueryService create(Ref ref) {
    return installmentQueryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallmentQueryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallmentQueryService>(value),
    );
  }
}

String _$installmentQueryServiceHash() =>
    r'd6e3e57e99b7f99d53bcfd931f587d7bbed71139';

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

String _$creditServiceHash() => r'e9ea48e1f74e9f1d78fbb03a7426e6d29dbde42d';
