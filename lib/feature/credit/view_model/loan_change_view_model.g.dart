// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_change_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanChangeViewModel)
final loanChangeViewModelProvider = LoanChangeViewModelFamily._();

final class LoanChangeViewModelProvider
    extends $NotifierProvider<LoanChangeViewModel, LoanChangeState> {
  LoanChangeViewModelProvider._({
    required LoanChangeViewModelFamily super.from,
    required LoanConfiguration? super.argument,
  }) : super(
         retry: null,
         name: r'loanChangeViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$loanChangeViewModelHash();

  @override
  String toString() {
    return r'loanChangeViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LoanChangeViewModel create() => LoanChangeViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoanChangeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoanChangeState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LoanChangeViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$loanChangeViewModelHash() =>
    r'36c4760090a768032e8ca6571353f111f2492a87';

final class LoanChangeViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          LoanChangeViewModel,
          LoanChangeState,
          LoanChangeState,
          LoanChangeState,
          LoanConfiguration?
        > {
  LoanChangeViewModelFamily._()
    : super(
        retry: null,
        name: r'loanChangeViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LoanChangeViewModelProvider call({LoanConfiguration? initial}) =>
      LoanChangeViewModelProvider._(argument: initial, from: this);

  @override
  String toString() => r'loanChangeViewModelProvider';
}

abstract class _$LoanChangeViewModel extends $Notifier<LoanChangeState> {
  late final _$args = ref.$arg as LoanConfiguration?;
  LoanConfiguration? get initial => _$args;

  LoanChangeState build({LoanConfiguration? initial});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LoanChangeState, LoanChangeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoanChangeState, LoanChangeState>,
              LoanChangeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(initial: _$args));
  }
}
