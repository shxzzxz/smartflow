// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_product_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentProductsViewModel)
final installmentProductsViewModelProvider =
    InstallmentProductsViewModelProvider._();

final class InstallmentProductsViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentProductsViewModel,
          List<InstallmentProductReadModel>
        > {
  InstallmentProductsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installmentProductsViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installmentProductsViewModelHash();

  @$internal
  @override
  InstallmentProductsViewModel create() => InstallmentProductsViewModel();
}

String _$installmentProductsViewModelHash() =>
    r'b609761ca35ffe55a75fb59250902d0393818bea';

abstract class _$InstallmentProductsViewModel
    extends $AsyncNotifier<List<InstallmentProductReadModel>> {
  FutureOr<List<InstallmentProductReadModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<InstallmentProductReadModel>>,
              List<InstallmentProductReadModel>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<InstallmentProductReadModel>>,
                List<InstallmentProductReadModel>
              >,
              AsyncValue<List<InstallmentProductReadModel>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(InstallmentProductEditViewModel)
final installmentProductEditViewModelProvider =
    InstallmentProductEditViewModelFamily._();

final class InstallmentProductEditViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentProductEditViewModel,
          InstallmentProductEditState
        > {
  InstallmentProductEditViewModelProvider._({
    required InstallmentProductEditViewModelFamily super.from,
    required (String?, bool) super.argument,
  }) : super(
         retry: null,
         name: r'installmentProductEditViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentProductEditViewModelHash();

  @override
  String toString() {
    return r'installmentProductEditViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  InstallmentProductEditViewModel create() => InstallmentProductEditViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentProductEditViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentProductEditViewModelHash() =>
    r'2329ba76049c4bfdaa2edea856abb751ee61a6d3';

final class InstallmentProductEditViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentProductEditViewModel,
          AsyncValue<InstallmentProductEditState>,
          InstallmentProductEditState,
          FutureOr<InstallmentProductEditState>,
          (String?, bool)
        > {
  InstallmentProductEditViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentProductEditViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentProductEditViewModelProvider call(String? productId, bool copy) =>
      InstallmentProductEditViewModelProvider._(
        argument: (productId, copy),
        from: this,
      );

  @override
  String toString() => r'installmentProductEditViewModelProvider';
}

abstract class _$InstallmentProductEditViewModel
    extends $AsyncNotifier<InstallmentProductEditState> {
  late final _$args = ref.$arg as (String?, bool);
  String? get productId => _$args.$1;
  bool get copy => _$args.$2;

  FutureOr<InstallmentProductEditState> build(String? productId, bool copy);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InstallmentProductEditState>,
              InstallmentProductEditState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentProductEditState>,
                InstallmentProductEditState
              >,
              AsyncValue<InstallmentProductEditState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
