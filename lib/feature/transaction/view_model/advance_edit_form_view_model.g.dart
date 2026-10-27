// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advance_edit_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdvanceEditFormViewModel)
final advanceEditFormViewModelProvider = AdvanceEditFormViewModelFamily._();

final class AdvanceEditFormViewModelProvider
    extends
        $AsyncNotifierProvider<AdvanceEditFormViewModel, AdvanceEditFormState> {
  AdvanceEditFormViewModelProvider._({
    required AdvanceEditFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'advanceEditFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$advanceEditFormViewModelHash();

  @override
  String toString() {
    return r'advanceEditFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AdvanceEditFormViewModel create() => AdvanceEditFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is AdvanceEditFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$advanceEditFormViewModelHash() =>
    r'037dd92b4e691193a6cdb5e735cb5e259f1323e6';

final class AdvanceEditFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          AdvanceEditFormViewModel,
          AsyncValue<AdvanceEditFormState>,
          AdvanceEditFormState,
          FutureOr<AdvanceEditFormState>,
          String
        > {
  AdvanceEditFormViewModelFamily._()
    : super(
        retry: null,
        name: r'advanceEditFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdvanceEditFormViewModelProvider call(String transactionId) =>
      AdvanceEditFormViewModelProvider._(argument: transactionId, from: this);

  @override
  String toString() => r'advanceEditFormViewModelProvider';
}

abstract class _$AdvanceEditFormViewModel
    extends $AsyncNotifier<AdvanceEditFormState> {
  late final _$args = ref.$arg as String;
  String get transactionId => _$args;

  FutureOr<AdvanceEditFormState> build(String transactionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AdvanceEditFormState>, AdvanceEditFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdvanceEditFormState>,
                AdvanceEditFormState
              >,
              AsyncValue<AdvanceEditFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
