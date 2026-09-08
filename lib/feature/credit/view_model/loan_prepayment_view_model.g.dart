// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_prepayment_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanPrepaymentViewModel)
final loanPrepaymentViewModelProvider = LoanPrepaymentViewModelProvider._();

final class LoanPrepaymentViewModelProvider
    extends $NotifierProvider<LoanPrepaymentViewModel, LoanPrepaymentState> {
  LoanPrepaymentViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loanPrepaymentViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loanPrepaymentViewModelHash();

  @$internal
  @override
  LoanPrepaymentViewModel create() => LoanPrepaymentViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoanPrepaymentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoanPrepaymentState>(value),
    );
  }
}

String _$loanPrepaymentViewModelHash() =>
    r'a12f7a964e6439bd224c94b70d7f2c5bfb7e1819';

abstract class _$LoanPrepaymentViewModel
    extends $Notifier<LoanPrepaymentState> {
  LoanPrepaymentState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LoanPrepaymentState, LoanPrepaymentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoanPrepaymentState, LoanPrepaymentState>,
              LoanPrepaymentState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
