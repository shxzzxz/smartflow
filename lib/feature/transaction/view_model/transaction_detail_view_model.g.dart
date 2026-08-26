// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TransactionDetailViewModel)
final transactionDetailViewModelProvider = TransactionDetailViewModelFamily._();

final class TransactionDetailViewModelProvider
    extends
        $AsyncNotifierProvider<
          TransactionDetailViewModel,
          TransactionDetailUiState
        > {
  TransactionDetailViewModelProvider._({
    required TransactionDetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transactionDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionDetailViewModelHash();

  @override
  String toString() {
    return r'transactionDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TransactionDetailViewModel create() => TransactionDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is TransactionDetailViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionDetailViewModelHash() =>
    r'dcb4d5dcf0146f9d9cbb2d2f5bba2597a9ee7349';

final class TransactionDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          TransactionDetailViewModel,
          AsyncValue<TransactionDetailUiState>,
          TransactionDetailUiState,
          FutureOr<TransactionDetailUiState>,
          String
        > {
  TransactionDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'transactionDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionDetailViewModelProvider call(String transactionId) =>
      TransactionDetailViewModelProvider._(argument: transactionId, from: this);

  @override
  String toString() => r'transactionDetailViewModelProvider';
}

abstract class _$TransactionDetailViewModel
    extends $AsyncNotifier<TransactionDetailUiState> {
  late final _$args = ref.$arg as String;
  String get transactionId => _$args;

  FutureOr<TransactionDetailUiState> build(String transactionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<TransactionDetailUiState>,
              TransactionDetailUiState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<TransactionDetailUiState>,
                TransactionDetailUiState
              >,
              AsyncValue<TransactionDetailUiState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
