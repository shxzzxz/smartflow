// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillDetailViewModel)
final billDetailViewModelProvider = BillDetailViewModelFamily._();

final class BillDetailViewModelProvider
    extends $AsyncNotifierProvider<BillDetailViewModel, BillDetailReadModel?> {
  BillDetailViewModelProvider._({
    required BillDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billDetailViewModelHash();

  @override
  String toString() {
    return r'billDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BillDetailViewModel create() => BillDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is BillDetailViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billDetailViewModelHash() =>
    r'a8c1d3b8a68f2ae139aa0e1865a83a4ba84212df';

final class BillDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          BillDetailViewModel,
          AsyncValue<BillDetailReadModel?>,
          BillDetailReadModel?,
          FutureOr<BillDetailReadModel?>,
          String
        > {
  BillDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'billDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillDetailViewModelProvider call(String billId) =>
      BillDetailViewModelProvider._(argument: billId, from: this);

  @override
  String toString() => r'billDetailViewModelProvider';
}

abstract class _$BillDetailViewModel
    extends $AsyncNotifier<BillDetailReadModel?> {
  late final _$args = ref.$arg as String;
  String get billId => _$args;

  FutureOr<BillDetailReadModel?> build(String billId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<BillDetailReadModel?>, BillDetailReadModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BillDetailReadModel?>,
                BillDetailReadModel?
              >,
              AsyncValue<BillDetailReadModel?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
