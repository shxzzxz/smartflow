// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_calculator_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanCalculatorViewModel)
final loanCalculatorViewModelProvider = LoanCalculatorViewModelProvider._();

final class LoanCalculatorViewModelProvider
    extends $NotifierProvider<LoanCalculatorViewModel, LoanCalculatorState> {
  LoanCalculatorViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loanCalculatorViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loanCalculatorViewModelHash();

  @$internal
  @override
  LoanCalculatorViewModel create() => LoanCalculatorViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoanCalculatorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoanCalculatorState>(value),
    );
  }
}

String _$loanCalculatorViewModelHash() =>
    r'74af78634c4928d9cc5ab50241e5c0f51dec5689';

abstract class _$LoanCalculatorViewModel
    extends $Notifier<LoanCalculatorState> {
  LoanCalculatorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LoanCalculatorState, LoanCalculatorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoanCalculatorState, LoanCalculatorState>,
              LoanCalculatorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
