// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment_operations_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InstallmentOperationsViewModel)
final installmentOperationsViewModelProvider =
    InstallmentOperationsViewModelFamily._();

final class InstallmentOperationsViewModelProvider
    extends
        $AsyncNotifierProvider<
          InstallmentOperationsViewModel,
          InstallmentOperationsState
        > {
  InstallmentOperationsViewModelProvider._({
    required InstallmentOperationsViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'installmentOperationsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$installmentOperationsViewModelHash();

  @override
  String toString() {
    return r'installmentOperationsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InstallmentOperationsViewModel create() => InstallmentOperationsViewModel();

  @override
  bool operator ==(Object other) {
    return other is InstallmentOperationsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$installmentOperationsViewModelHash() =>
    r'77a1429861e45f4a9beb45836fc6bedda549fc3f';

final class InstallmentOperationsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          InstallmentOperationsViewModel,
          AsyncValue<InstallmentOperationsState>,
          InstallmentOperationsState,
          FutureOr<InstallmentOperationsState>,
          String
        > {
  InstallmentOperationsViewModelFamily._()
    : super(
        retry: null,
        name: r'installmentOperationsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InstallmentOperationsViewModelProvider call(String contractId) =>
      InstallmentOperationsViewModelProvider._(
        argument: contractId,
        from: this,
      );

  @override
  String toString() => r'installmentOperationsViewModelProvider';
}

abstract class _$InstallmentOperationsViewModel
    extends $AsyncNotifier<InstallmentOperationsState> {
  late final _$args = ref.$arg as String;
  String get contractId => _$args;

  FutureOr<InstallmentOperationsState> build(String contractId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InstallmentOperationsState>,
              InstallmentOperationsState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InstallmentOperationsState>,
                InstallmentOperationsState
              >,
              AsyncValue<InstallmentOperationsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
