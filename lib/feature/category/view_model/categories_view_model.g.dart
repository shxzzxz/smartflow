// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoriesViewModel)
final categoriesViewModelProvider = CategoriesViewModelProvider._();

final class CategoriesViewModelProvider
    extends $NotifierProvider<CategoriesViewModel, void> {
  CategoriesViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesViewModelHash();

  @$internal
  @override
  CategoriesViewModel create() => CategoriesViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$categoriesViewModelHash() =>
    r'bf2007ef9f6d24f9c90d30aa407f7cf03fb8e6de';

abstract class _$CategoriesViewModel extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
