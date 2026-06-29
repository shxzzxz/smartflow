// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountFormViewModel)
final accountFormViewModelProvider = AccountFormViewModelProvider._();

final class AccountFormViewModelProvider
    extends $NotifierProvider<AccountFormViewModel, AccountFormState> {
  AccountFormViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountFormViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountFormViewModelHash();

  @$internal
  @override
  AccountFormViewModel create() => AccountFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountFormState>(value),
    );
  }
}

String _$accountFormViewModelHash() =>
    r'f4ec63f88bd1513a1bfaab5069e13909ce39067f';

abstract class _$AccountFormViewModel extends $Notifier<AccountFormState> {
  AccountFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AccountFormState, AccountFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountFormState, AccountFormState>,
              AccountFormState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
