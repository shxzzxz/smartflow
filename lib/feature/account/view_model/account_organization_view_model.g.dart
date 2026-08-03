// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_organization_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 资产页的账户展示组织命令入口。
///
/// 分组和排序都是展示组织，不改变账户画像或账务余额。

@ProviderFor(AccountOrganizationViewModel)
final accountOrganizationViewModelProvider =
    AccountOrganizationViewModelProvider._();

/// 资产页的账户展示组织命令入口。
///
/// 分组和排序都是展示组织，不改变账户画像或账务余额。
final class AccountOrganizationViewModelProvider
    extends $NotifierProvider<AccountOrganizationViewModel, void> {
  /// 资产页的账户展示组织命令入口。
  ///
  /// 分组和排序都是展示组织，不改变账户画像或账务余额。
  AccountOrganizationViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountOrganizationViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountOrganizationViewModelHash();

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
}

String _$accountOrganizationViewModelHash() =>
    r'c1a878e557c22f52c3a58776ed0629652a028f35';

/// 资产页的账户展示组织命令入口。
///
/// 分组和排序都是展示组织，不改变账户画像或账务余额。

abstract class _$AccountOrganizationViewModel extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
