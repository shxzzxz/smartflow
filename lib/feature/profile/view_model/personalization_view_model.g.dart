// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personalization_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PersonalizationViewModel)
final personalizationViewModelProvider = PersonalizationViewModelProvider._();

final class PersonalizationViewModelProvider
    extends
        $AsyncNotifierProvider<PersonalizationViewModel, PersonalizationState> {
  PersonalizationViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalizationViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalizationViewModelHash();

  @$internal
  @override
  PersonalizationViewModel create() => PersonalizationViewModel();
}

String _$personalizationViewModelHash() =>
    r'2fb1a1e0d5cfd12a4d701a284c70e79b4d0da486';

abstract class _$PersonalizationViewModel
    extends $AsyncNotifier<PersonalizationState> {
  FutureOr<PersonalizationState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PersonalizationState>, PersonalizationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PersonalizationState>,
                PersonalizationState
              >,
              AsyncValue<PersonalizationState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
