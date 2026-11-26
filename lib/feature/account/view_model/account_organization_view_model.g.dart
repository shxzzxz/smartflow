// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_organization_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// All organization commands apply to one saved asset view.

@ProviderFor(AccountOrganizationViewModel)
final accountOrganizationViewModelProvider =
    AccountOrganizationViewModelFamily._();

/// All organization commands apply to one saved asset view.
final class AccountOrganizationViewModelProvider
    extends $NotifierProvider<AccountOrganizationViewModel, void> {
  /// All organization commands apply to one saved asset view.
  AccountOrganizationViewModelProvider._({
    required AccountOrganizationViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountOrganizationViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountOrganizationViewModelHash();

  @override
  String toString() {
    return r'accountOrganizationViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountOrganizationViewModel create() => AccountOrganizationViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountOrganizationViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountOrganizationViewModelHash() =>
    r'0540d5bdd413778ba9a8b2a07c6a64f19a18d963';

/// All organization commands apply to one saved asset view.

final class AccountOrganizationViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountOrganizationViewModel,
          void,
          void,
          void,
          String
        > {
  AccountOrganizationViewModelFamily._()
    : super(
        retry: null,
        name: r'accountOrganizationViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// All organization commands apply to one saved asset view.

  AccountOrganizationViewModelProvider call(String viewId) =>
      AccountOrganizationViewModelProvider._(argument: viewId, from: this);

  @override
  String toString() => r'accountOrganizationViewModelProvider';
}

/// All organization commands apply to one saved asset view.

abstract class _$AccountOrganizationViewModel extends $Notifier<void> {
  late final _$args = ref.$arg as String;
  String get viewId => _$args;

  void build(String viewId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
