// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_configuration_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoanConfigurationViewModel)
final loanConfigurationViewModelProvider = LoanConfigurationViewModelFamily._();

final class LoanConfigurationViewModelProvider
    extends
        $NotifierProvider<LoanConfigurationViewModel, LoanConfigurationState> {
  LoanConfigurationViewModelProvider._({
    required LoanConfigurationViewModelFamily super.from,
    required ({
      LoanConfiguration? initial,
      bool selection,
      InstallmentConfigurationDraft? installment,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'loanConfigurationViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$loanConfigurationViewModelHash();

  @override
  String toString() {
    return r'loanConfigurationViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  LoanConfigurationViewModel create() => LoanConfigurationViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoanConfigurationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoanConfigurationState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LoanConfigurationViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$loanConfigurationViewModelHash() =>
    r'2017aa76dcfc16565c22021ad24029f1f1a57b03';

final class LoanConfigurationViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          LoanConfigurationViewModel,
          LoanConfigurationState,
          LoanConfigurationState,
          LoanConfigurationState,
          ({
            LoanConfiguration? initial,
            bool selection,
            InstallmentConfigurationDraft? installment,
          })
        > {
  LoanConfigurationViewModelFamily._()
    : super(
        retry: null,
        name: r'loanConfigurationViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LoanConfigurationViewModelProvider call({
    LoanConfiguration? initial,
    bool selection = false,
    InstallmentConfigurationDraft? installment,
  }) => LoanConfigurationViewModelProvider._(
    argument: (
      initial: initial,
      selection: selection,
      installment: installment,
    ),
    from: this,
  );

  @override
  String toString() => r'loanConfigurationViewModelProvider';
}

abstract class _$LoanConfigurationViewModel
    extends $Notifier<LoanConfigurationState> {
  late final _$args =
      ref.$arg
          as ({
            LoanConfiguration? initial,
            bool selection,
            InstallmentConfigurationDraft? installment,
          });
  LoanConfiguration? get initial => _$args.initial;
  bool get selection => _$args.selection;
  InstallmentConfigurationDraft? get installment => _$args.installment;

  LoanConfigurationState build({
    LoanConfiguration? initial,
    bool selection = false,
    InstallmentConfigurationDraft? installment,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<LoanConfigurationState, LoanConfigurationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoanConfigurationState, LoanConfigurationState>,
              LoanConfigurationState,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        initial: _$args.initial,
        selection: _$args.selection,
        installment: _$args.installment,
      ),
    );
  }
}
