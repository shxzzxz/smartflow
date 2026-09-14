// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_comparison_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanComparisonViewModel)
final loanComparisonViewModelProvider = LoanComparisonViewModelFamily._();

final class LoanComparisonViewModelProvider
    extends $NotifierProvider<LoanComparisonViewModel, LoanComparisonState> {
  LoanComparisonViewModelProvider._({
    required LoanComparisonViewModelFamily super.from,
    required LoanConfiguration? super.argument,
  }) : super(
         retry: null,
         name: r'loanComparisonViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$loanComparisonViewModelHash();

  @override
  String toString() {
    return r'loanComparisonViewModelProvider'
        ''
        '($argument)';
  }

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

  @override
  bool operator ==(Object other) {
    return other is LoanComparisonViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$loanComparisonViewModelHash() =>
    r'fec057cc1f99a9a397644f8c68f90a4e0129b50e';

final class LoanComparisonViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          LoanComparisonViewModel,
          LoanComparisonState,
          LoanComparisonState,
          LoanComparisonState,
          LoanConfiguration?
        > {
  LoanComparisonViewModelFamily._()
    : super(
        retry: null,
        name: r'loanComparisonViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LoanComparisonViewModelProvider call({LoanConfiguration? initial}) =>
      LoanComparisonViewModelProvider._(argument: initial, from: this);

  @override
  String toString() => r'loanComparisonViewModelProvider';
}

abstract class _$LoanComparisonViewModel
    extends $Notifier<LoanComparisonState> {
  late final _$args = ref.$arg as LoanConfiguration?;
  LoanConfiguration? get initial => _$args;

  LoanComparisonState build({LoanConfiguration? initial});
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
    return element.handleCreate(ref, () => build(initial: _$args));
  }
}
