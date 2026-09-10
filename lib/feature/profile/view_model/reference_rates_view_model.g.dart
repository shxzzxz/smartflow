// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_rates_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferenceRatesViewModel)
final referenceRatesViewModelProvider = ReferenceRatesViewModelProvider._();

final class ReferenceRatesViewModelProvider
    extends $NotifierProvider<ReferenceRatesViewModel, ReferenceRatesState> {
  ReferenceRatesViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referenceRatesViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referenceRatesViewModelHash();

  @$internal
  @override
  ReferenceRatesViewModel create() => ReferenceRatesViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferenceRatesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferenceRatesState>(value),
    );
  }
}

String _$referenceRatesViewModelHash() =>
    r'5ffb3f7dec6945766727bcb49f219e3aef45e12f';

abstract class _$ReferenceRatesViewModel
    extends $Notifier<ReferenceRatesState> {
  ReferenceRatesState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReferenceRatesState, ReferenceRatesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReferenceRatesState, ReferenceRatesState>,
              ReferenceRatesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
