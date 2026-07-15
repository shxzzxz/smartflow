// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_repayment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillRepaymentFormViewModel)
final billRepaymentFormViewModelProvider = BillRepaymentFormViewModelFamily._();

final class BillRepaymentFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          BillRepaymentFormViewModel,
          BillRepaymentFormState
        > {
  BillRepaymentFormViewModelProvider._({
    required BillRepaymentFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billRepaymentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billRepaymentFormViewModelHash();

  @override
  String toString() {
    return r'billRepaymentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BillRepaymentFormViewModel create() => BillRepaymentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is BillRepaymentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billRepaymentFormViewModelHash() =>
    r'ca551a7b7d2350aef34c9b09223b1ff108f68494';

final class BillRepaymentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          BillRepaymentFormViewModel,
          AsyncValue<BillRepaymentFormState>,
          BillRepaymentFormState,
          FutureOr<BillRepaymentFormState>,
          String
        > {
  BillRepaymentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'billRepaymentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillRepaymentFormViewModelProvider call(String billId) =>
      BillRepaymentFormViewModelProvider._(argument: billId, from: this);

  @override
  String toString() => r'billRepaymentFormViewModelProvider';
}

abstract class _$BillRepaymentFormViewModel
    extends $AsyncNotifier<BillRepaymentFormState> {
  late final _$args = ref.$arg as String;
  String get billId => _$args;

  FutureOr<BillRepaymentFormState> build(String billId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<BillRepaymentFormState>, BillRepaymentFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BillRepaymentFormState>,
                BillRepaymentFormState
              >,
              AsyncValue<BillRepaymentFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
