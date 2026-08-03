// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_accounts_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
    r'b3afaa233fc2618afb8658e1bbdb00af43d39635';

abstract class _$ArchivedAccountsViewModel
    extends $Notifier<ArchivedAccountsPageState> {
  ArchivedAccountsPageState build();
  @$mustCallSuper
  @override
  void runBuild() {
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
    element.handleCreate(ref, build);
  }
}
