// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_views_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountViews)
final accountViewsProvider = AccountViewsProvider._();

final class AccountViewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountView>>,
          AsyncValue<List<AccountView>>,
          AsyncValue<List<AccountView>>
        >
    with $Provider<AsyncValue<List<AccountView>>> {
  AccountViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountViewsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<AccountView>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<AccountView>> create(Ref ref) {
    return accountViews(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<AccountView>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<AccountView>>>(
        value,
      ),
    );
  }
}

String _$accountViewsHash() => r'acb57b35e59e785b9cf5bcf9868ba853c27c757d';

@ProviderFor(accountView)
final accountViewProvider = AccountViewFamily._();

final class AccountViewProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountView?>,
          AsyncValue<AccountView?>,
          AsyncValue<AccountView?>
        >
    with $Provider<AsyncValue<AccountView?>> {
  AccountViewProvider._({
    required AccountViewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountViewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountViewHash();

  @override
  String toString() {
    return r'accountViewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<AccountView?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AccountView?> create(Ref ref) {
    final argument = this.argument as String;
    return accountView(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AccountView?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AccountView?>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountViewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountViewHash() => r'953fc08c84be0f3abbddc56b981f022e22d7fe4f';

final class AccountViewFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<AccountView?>, String> {
  AccountViewFamily._()
    : super(
        retry: null,
        name: r'accountViewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountViewProvider call(String accountId) =>
      AccountViewProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountViewProvider';
}

@ProviderFor(accountById)
final accountByIdProvider = AccountByIdFamily._();

final class AccountByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Account?>, Account?, FutureOr<Account?>>
    with $FutureModifier<Account?>, $FutureProvider<Account?> {
  AccountByIdProvider._({
    required AccountByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountByIdHash();

  @override
  String toString() {
    return r'accountByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Account?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Account?> create(Ref ref) {
    final argument = this.argument as String;
    return accountById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountByIdHash() => r'0aeade261cff0ff95ef1604575c9820cc1dab7d0';

final class AccountByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Account?>, String> {
  AccountByIdFamily._()
    : super(
        retry: null,
        name: r'accountByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountByIdProvider call(String accountId) =>
      AccountByIdProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountByIdProvider';
}
