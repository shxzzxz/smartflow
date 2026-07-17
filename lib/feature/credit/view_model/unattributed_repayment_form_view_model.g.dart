// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unattributed_repayment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UnattributedRepaymentFormViewModel)
final unattributedRepaymentFormViewModelProvider =
    UnattributedRepaymentFormViewModelFamily._();

final class UnattributedRepaymentFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          UnattributedRepaymentFormViewModel,
          UnattributedRepaymentFormState
        > {
  UnattributedRepaymentFormViewModelProvider._({
    required UnattributedRepaymentFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'unattributedRepaymentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$unattributedRepaymentFormViewModelHash();

  @override
  String toString() {
    return r'unattributedRepaymentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UnattributedRepaymentFormViewModel create() =>
      UnattributedRepaymentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is UnattributedRepaymentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$unattributedRepaymentFormViewModelHash() =>
    r'2e342ea8a686a71825e1b9114348fa7cffc1eff8';

final class UnattributedRepaymentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          UnattributedRepaymentFormViewModel,
          AsyncValue<UnattributedRepaymentFormState>,
          UnattributedRepaymentFormState,
          FutureOr<UnattributedRepaymentFormState>,
          String
        > {
  UnattributedRepaymentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'unattributedRepaymentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UnattributedRepaymentFormViewModelProvider call(String accountId) =>
      UnattributedRepaymentFormViewModelProvider._(
        argument: accountId,
        from: this,
      );

  @override
  String toString() => r'unattributedRepaymentFormViewModelProvider';
}

abstract class _$UnattributedRepaymentFormViewModel
    extends $AsyncNotifier<UnattributedRepaymentFormState> {
  late final _$args = ref.$arg as String;
  String get accountId => _$args;

  FutureOr<UnattributedRepaymentFormState> build(String accountId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<UnattributedRepaymentFormState>,
              UnattributedRepaymentFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<UnattributedRepaymentFormState>,
                UnattributedRepaymentFormState
              >,
              AsyncValue<UnattributedRepaymentFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
