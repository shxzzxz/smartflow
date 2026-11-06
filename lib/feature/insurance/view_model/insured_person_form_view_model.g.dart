// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insured_person_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InsuredPersonFormViewModel)
final insuredPersonFormViewModelProvider = InsuredPersonFormViewModelFamily._();

final class InsuredPersonFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          InsuredPersonFormViewModel,
          InsuredPersonFormState?
        > {
  InsuredPersonFormViewModelProvider._({
    required InsuredPersonFormViewModelFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'insuredPersonFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$insuredPersonFormViewModelHash();

  @override
  String toString() {
    return r'insuredPersonFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InsuredPersonFormViewModel create() => InsuredPersonFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is InsuredPersonFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$insuredPersonFormViewModelHash() =>
    r'4c8bd87487aae493e40173e26105e95eb42fbc44';

final class InsuredPersonFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InsuredPersonFormViewModel,
          AsyncValue<InsuredPersonFormState?>,
          InsuredPersonFormState?,
          FutureOr<InsuredPersonFormState?>,
          String?
        > {
  InsuredPersonFormViewModelFamily._()
    : super(
        retry: null,
        name: r'insuredPersonFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InsuredPersonFormViewModelProvider call(String? personId) =>
      InsuredPersonFormViewModelProvider._(argument: personId, from: this);

  @override
  String toString() => r'insuredPersonFormViewModelProvider';
}

abstract class _$InsuredPersonFormViewModel
    extends $AsyncNotifier<InsuredPersonFormState?> {
  late final _$args = ref.$arg as String?;
  String? get personId => _$args;

  FutureOr<InsuredPersonFormState?> build(String? personId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InsuredPersonFormState?>,
              InsuredPersonFormState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InsuredPersonFormState?>,
                InsuredPersonFormState?
              >,
              AsyncValue<InsuredPersonFormState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
