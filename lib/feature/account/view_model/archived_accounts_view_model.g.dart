// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_accounts_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(scopedArchivedAccountsPage)
final scopedArchivedAccountsPageProvider = ScopedArchivedAccountsPageFamily._();

final class ScopedArchivedAccountsPageProvider
    extends
        $FunctionalProvider<
          ArchivedAccountsPageState,
          ArchivedAccountsPageState,
          ArchivedAccountsPageState
        >
    with $Provider<ArchivedAccountsPageState> {
  ScopedArchivedAccountsPageProvider._({
    required ScopedArchivedAccountsPageFamily super.from,
    required (Set<String>?, AccountType?, {String? viewId}) super.argument,
  }) : super(
         retry: null,
         name: r'scopedArchivedAccountsPageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scopedArchivedAccountsPageHash();

  @override
  String toString() {
    return r'scopedArchivedAccountsPageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<ArchivedAccountsPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ArchivedAccountsPageState create(Ref ref) {
    final argument =
        this.argument as (Set<String>?, AccountType?, {String? viewId});
    return scopedArchivedAccountsPage(
      ref,
      argument.$1,
      argument.$2,
      viewId: argument.viewId,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchivedAccountsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchivedAccountsPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScopedArchivedAccountsPageProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scopedArchivedAccountsPageHash() =>
    r'c3014303ace9407ed5ea669852858f7de483c0e8';

final class ScopedArchivedAccountsPageFamily extends $Family
    with
        $FunctionalFamilyOverride<
          ArchivedAccountsPageState,
          (Set<String>?, AccountType?, {String? viewId})
        > {
  ScopedArchivedAccountsPageFamily._()
    : super(
        retry: null,
        name: r'scopedArchivedAccountsPageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ScopedArchivedAccountsPageProvider call(
    Set<String>? accountIds,
    AccountType? accountType, {
    String? viewId,
  }) => ScopedArchivedAccountsPageProvider._(
    argument: (accountIds, accountType, viewId: viewId),
    from: this,
  );

  @override
  String toString() => r'scopedArchivedAccountsPageProvider';
}

@ProviderFor(ArchivedAccountsViewModel)
final archivedAccountsViewModelProvider = ArchivedAccountsViewModelProvider._();

final class ArchivedAccountsViewModelProvider
    extends
        $NotifierProvider<
          ArchivedAccountsViewModel,
          ArchivedAccountsPageState
        > {
  ArchivedAccountsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedAccountsViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedAccountsViewModelHash();

  @$internal
  @override
  ArchivedAccountsViewModel create() => ArchivedAccountsViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchivedAccountsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchivedAccountsPageState>(value),
    );
  }
}

String _$archivedAccountsViewModelHash() =>
    r'd5e76ffeaed780e2d8744425ae99765b1d4253ad';

abstract class _$ArchivedAccountsViewModel
    extends $Notifier<ArchivedAccountsPageState> {
  ArchivedAccountsPageState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ArchivedAccountsPageState, ArchivedAccountsPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ArchivedAccountsPageState, ArchivedAccountsPageState>,
              ArchivedAccountsPageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
