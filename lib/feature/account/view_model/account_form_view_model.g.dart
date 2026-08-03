// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountFormViewModel)
final accountFormViewModelProvider = AccountFormViewModelFamily._();

final class AccountFormViewModelProvider
    extends
        $NotifierProvider<AccountFormViewModel, AsyncValue<AccountFormState?>> {
  AccountFormViewModelProvider._({
    required AccountFormViewModelFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'accountFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountFormViewModelHash();

  @override
  String toString() {
    return r'accountFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AccountFormViewModel create() => AccountFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AccountFormState?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AccountFormState?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountFormViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountFormViewModelHash() =>
    r'eaabd1152657aa05408d720f42eaace6357a09b0';

final class AccountFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AccountFormViewModel,
          AsyncValue<AccountFormState?>,
          AsyncValue<AccountFormState?>,
          AsyncValue<AccountFormState?>,
          String?
        > {
  AccountFormViewModelFamily._()
    : super(
        retry: null,
        name: r'accountFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountFormViewModelProvider call(String? accountId) =>
      AccountFormViewModelProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountFormViewModelProvider';
}

abstract class _$AccountFormViewModel
    extends $Notifier<AsyncValue<AccountFormState?>> {
  late final _$args = ref.$arg as String?;
  String? get accountId => _$args;

  AsyncValue<AccountFormState?> build(String? accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AccountFormState?>,
              AsyncValue<AccountFormState?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AccountFormState?>,
                AsyncValue<AccountFormState?>
              >,
              AsyncValue<AccountFormState?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
