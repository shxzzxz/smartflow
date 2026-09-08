// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_comparison_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanComparisonViewModel)
final loanComparisonViewModelProvider = LoanComparisonViewModelProvider._();

final class LoanComparisonViewModelProvider
    extends $NotifierProvider<LoanComparisonViewModel, LoanComparisonState> {
  LoanComparisonViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loanComparisonViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loanComparisonViewModelHash();

  @$internal
  @override
  LoanComparisonViewModel create() => LoanComparisonViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoanComparisonState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoanComparisonState>(value),
    );
  }
}

String _$loanComparisonViewModelHash() =>
    r'452506f995591ed6df2507fca1fd23ee48dc430b';

abstract class _$LoanComparisonViewModel
    extends $Notifier<LoanComparisonState> {
  LoanComparisonState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LoanComparisonState, LoanComparisonState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoanComparisonState, LoanComparisonState>,
              LoanComparisonState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
