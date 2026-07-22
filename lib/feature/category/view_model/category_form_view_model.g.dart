// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoryFormViewModel)
final categoryFormViewModelProvider = CategoryFormViewModelFamily._();

final class CategoryFormViewModelProvider
    extends
        $NotifierProvider<
          CategoryFormViewModel,
          AsyncValue<CategoryFormState?>
        > {
  CategoryFormViewModelProvider._({
    required CategoryFormViewModelFamily super.from,
    required ({
      String? categoryId,
      AccountType initialType,
      String? initialParentId,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'categoryFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryFormViewModelHash();

  @override
  String toString() {
    return r'categoryFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CategoryFormViewModel create() => CategoryFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<CategoryFormState?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<CategoryFormState?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryFormViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryFormViewModelHash() =>
    r'a066c274953c7ce52c8634c110c1e4fff35b4831';

final class CategoryFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CategoryFormViewModel,
          AsyncValue<CategoryFormState?>,
          AsyncValue<CategoryFormState?>,
          AsyncValue<CategoryFormState?>,
          ({
            String? categoryId,
            AccountType initialType,
            String? initialParentId,
          })
        > {
  CategoryFormViewModelFamily._()
    : super(
        retry: null,
        name: r'categoryFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CategoryFormViewModelProvider call({
    String? categoryId,
    AccountType initialType = AccountType.expense,
    String? initialParentId,
  }) => CategoryFormViewModelProvider._(
    argument: (
      categoryId: categoryId,
      initialType: initialType,
      initialParentId: initialParentId,
    ),
    from: this,
  );

  @override
  String toString() => r'categoryFormViewModelProvider';
}

abstract class _$CategoryFormViewModel
    extends $Notifier<AsyncValue<CategoryFormState?>> {
  late final _$args =
      ref.$arg
          as ({
            String? categoryId,
            AccountType initialType,
            String? initialParentId,
          });
  String? get categoryId => _$args.categoryId;
  AccountType get initialType => _$args.initialType;
  String? get initialParentId => _$args.initialParentId;

  AsyncValue<CategoryFormState?> build({
    String? categoryId,
    AccountType initialType = AccountType.expense,
    String? initialParentId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CategoryFormState?>,
              AsyncValue<CategoryFormState?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CategoryFormState?>,
                AsyncValue<CategoryFormState?>
              >,
              AsyncValue<CategoryFormState?>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        categoryId: _$args.categoryId,
        initialType: _$args.initialType,
        initialParentId: _$args.initialParentId,
      ),
    );
  }
}
