// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_conversion_installment_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillConversionInstallmentFormViewModel)
final billConversionInstallmentFormViewModelProvider =
    BillConversionInstallmentFormViewModelFamily._();

final class BillConversionInstallmentFormViewModelProvider
    extends
        $AsyncNotifierProvider<
          BillConversionInstallmentFormViewModel,
          BillConversionInstallmentFormState
        > {
  BillConversionInstallmentFormViewModelProvider._({
    required BillConversionInstallmentFormViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billConversionInstallmentFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$billConversionInstallmentFormViewModelHash();

  @override
  String toString() {
    return r'billConversionInstallmentFormViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BillConversionInstallmentFormViewModel create() =>
      BillConversionInstallmentFormViewModel();

  @override
  bool operator ==(Object other) {
    return other is BillConversionInstallmentFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billConversionInstallmentFormViewModelHash() =>
    r'53400126ec76e66210a816746ef864114ffa1cd5';

final class BillConversionInstallmentFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          BillConversionInstallmentFormViewModel,
          AsyncValue<BillConversionInstallmentFormState>,
          BillConversionInstallmentFormState,
          FutureOr<BillConversionInstallmentFormState>,
          String
        > {
  BillConversionInstallmentFormViewModelFamily._()
    : super(
        retry: null,
        name: r'billConversionInstallmentFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillConversionInstallmentFormViewModelProvider call(String billId) =>
      BillConversionInstallmentFormViewModelProvider._(
        argument: billId,
        from: this,
      );

  @override
  String toString() => r'billConversionInstallmentFormViewModelProvider';
}

abstract class _$BillConversionInstallmentFormViewModel
    extends $AsyncNotifier<BillConversionInstallmentFormState> {
  late final _$args = ref.$arg as String;
  String get billId => _$args;

  FutureOr<BillConversionInstallmentFormState> build(String billId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<BillConversionInstallmentFormState>,
              BillConversionInstallmentFormState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BillConversionInstallmentFormState>,
                BillConversionInstallmentFormState
              >,
              AsyncValue<BillConversionInstallmentFormState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
