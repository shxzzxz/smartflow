// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RefundFormViewModel)
final refundFormViewModelProvider = RefundFormViewModelFamily._();

final class RefundFormViewModelProvider
    extends $AsyncNotifierProvider<RefundFormViewModel, RefundFormState> {
  RefundFormViewModelProvider._({
    required RefundFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'refundFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$refundFormViewModelHash();

  @override
  String toString() {
    return r'refundFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RefundFormViewModel create() => RefundFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is RefundFormViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$refundFormViewModelHash() =>
    r'b81e29d12642d799f7d8072aa922596d8a651cd6';

final class RefundFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          RefundFormViewModel,
          AsyncValue<RefundFormState>,
          RefundFormState,
          FutureOr<RefundFormState>,
          String
        > {
  RefundFormViewModelFamily._()
    : super(
        retry: null,
        name: r'refundFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RefundFormViewModelProvider call(String parentTransactionId) =>
      RefundFormViewModelProvider._(argument: parentTransactionId, from: this);

  @override
  String toString() => r'refundFormViewModelProvider';
}

abstract class _$RefundFormViewModel extends $AsyncNotifier<RefundFormState> {
  late final _$args = ref.$arg as String;
  String get parentTransactionId => _$args;

  FutureOr<RefundFormState> build(String parentTransactionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RefundFormState>, RefundFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RefundFormState>, RefundFormState>,
              AsyncValue<RefundFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
