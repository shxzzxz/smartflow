// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoryFormViewModel)
final categoryFormViewModelProvider = CategoryFormViewModelProvider._();

final class CategoryFormViewModelProvider
    extends $NotifierProvider<CategoryFormViewModel, CategoryFormState> {
  CategoryFormViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryFormViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryFormViewModelHash();

  @$internal
  @override
  CategoryFormViewModel create() => CategoryFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryFormState>(value),
    );
  }
}

String _$categoryFormViewModelHash() =>
    r'15772d63eb5e26f6b5f3c2d9b4f8fe5a32c78055';

abstract class _$CategoryFormViewModel extends $Notifier<CategoryFormState> {
  CategoryFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CategoryFormState, CategoryFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CategoryFormState, CategoryFormState>,
              CategoryFormState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
