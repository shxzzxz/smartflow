// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_edit_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillEditViewModel)
final billEditViewModelProvider = BillEditViewModelFamily._();

final class BillEditViewModelProvider
    extends $AsyncNotifierProvider<BillEditViewModel, BillEditFormState> {
  BillEditViewModelProvider._({
    required BillEditViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billEditViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billEditViewModelHash();

  @override
  String toString() {
    return r'billEditViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BillEditViewModel create() => BillEditViewModel();

  @override
  bool operator ==(Object other) {
    return other is BillEditViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billEditViewModelHash() => r'761b1ceea66115a2d8cdcb4d042610ecbb148e56';

final class BillEditViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          BillEditViewModel,
          AsyncValue<BillEditFormState>,
          BillEditFormState,
          FutureOr<BillEditFormState>,
          String
        > {
  BillEditViewModelFamily._()
    : super(
        retry: null,
        name: r'billEditViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillEditViewModelProvider call(String billId) =>
      BillEditViewModelProvider._(argument: billId, from: this);

  @override
  String toString() => r'billEditViewModelProvider';
}

abstract class _$BillEditViewModel extends $AsyncNotifier<BillEditFormState> {
  late final _$args = ref.$arg as String;
  String get billId => _$args;

  FutureOr<BillEditFormState> build(String billId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<BillEditFormState>, BillEditFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BillEditFormState>, BillEditFormState>,
              AsyncValue<BillEditFormState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
