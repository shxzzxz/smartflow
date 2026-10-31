// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amortization_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AmortizationFormViewModel)
final amortizationFormViewModelProvider = AmortizationFormViewModelFamily._();

final class AmortizationFormViewModelProvider
    extends
        $NotifierProvider<
          AmortizationFormViewModel,
          AsyncValue<AmortizationFormState>
        > {
  AmortizationFormViewModelProvider._({
    required AmortizationFormViewModelFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: null,
         name: r'amortizationFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$amortizationFormViewModelHash();

  @override
  String toString() {
    return r'amortizationFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AmortizationFormViewModel create() => AmortizationFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AmortizationFormState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AmortizationFormState>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AmortizationFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$amortizationFormViewModelHash() =>
    r'4428000091ed4bff02a133915a297f85ebc2a632';

final class AmortizationFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AmortizationFormViewModel,
          AsyncValue<AmortizationFormState>,
          AsyncValue<AmortizationFormState>,
          AsyncValue<AmortizationFormState>,
          (String, String?)
        > {
  AmortizationFormViewModelFamily._()
    : super(
        retry: null,
        name: r'amortizationFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AmortizationFormViewModelProvider call(
    String initialKind,
    String? initialDeferralAccountId,
  ) => AmortizationFormViewModelProvider._(
    argument: (initialKind, initialDeferralAccountId),
    from: this,
  );

  @override
  String toString() => r'amortizationFormViewModelProvider';
}

abstract class _$AmortizationFormViewModel
    extends $Notifier<AsyncValue<AmortizationFormState>> {
  late final _$args = ref.$arg as (String, String?);
  String get initialKind => _$args.$1;
  String? get initialDeferralAccountId => _$args.$2;

  AsyncValue<AmortizationFormState> build(
    String initialKind,
    String? initialDeferralAccountId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AmortizationFormState>,
              AsyncValue<AmortizationFormState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AmortizationFormState>,
                AsyncValue<AmortizationFormState>
              >,
              AsyncValue<AmortizationFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
