// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_form_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TransactionFormViewModel)
final transactionFormViewModelProvider = TransactionFormViewModelFamily._();

final class TransactionFormViewModelProvider
    extends
        $NotifierProvider<
          TransactionFormViewModel,
          AsyncValue<TransactionFormState?>
        > {
  TransactionFormViewModelProvider._({
    required TransactionFormViewModelFamily super.from,
    required ({
      String? editTransactionId,
      TransactionFormMode initialMode,
      String? initialFromAccountId,
      String? initialToAccountId,
      String? initialLiabilityAccountId,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'transactionFormViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionFormViewModelHash();

  @override
  String toString() {
    return r'transactionFormViewModelProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  TransactionFormViewModel create() => TransactionFormViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<TransactionFormState?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<TransactionFormState?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionFormViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionFormViewModelHash() =>
    r'4b631db58465e6520d07065c43141111f8920c29';

final class TransactionFormViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          TransactionFormViewModel,
          AsyncValue<TransactionFormState?>,
          AsyncValue<TransactionFormState?>,
          AsyncValue<TransactionFormState?>,
          ({
            String? editTransactionId,
            TransactionFormMode initialMode,
            String? initialFromAccountId,
            String? initialToAccountId,
            String? initialLiabilityAccountId,
          })
        > {
  TransactionFormViewModelFamily._()
    : super(
        retry: null,
        name: r'transactionFormViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionFormViewModelProvider call({
    String? editTransactionId,
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
    String? initialLiabilityAccountId,
  }) => TransactionFormViewModelProvider._(
    argument: (
      editTransactionId: editTransactionId,
      initialMode: initialMode,
      initialFromAccountId: initialFromAccountId,
      initialToAccountId: initialToAccountId,
      initialLiabilityAccountId: initialLiabilityAccountId,
    ),
    from: this,
  );

  @override
  String toString() => r'transactionFormViewModelProvider';
}

abstract class _$TransactionFormViewModel
    extends $Notifier<AsyncValue<TransactionFormState?>> {
  late final _$args =
      ref.$arg
          as ({
            String? editTransactionId,
            TransactionFormMode initialMode,
            String? initialFromAccountId,
            String? initialToAccountId,
            String? initialLiabilityAccountId,
          });
  String? get editTransactionId => _$args.editTransactionId;
  TransactionFormMode get initialMode => _$args.initialMode;
  String? get initialFromAccountId => _$args.initialFromAccountId;
  String? get initialToAccountId => _$args.initialToAccountId;
  String? get initialLiabilityAccountId => _$args.initialLiabilityAccountId;

  AsyncValue<TransactionFormState?> build({
    String? editTransactionId,
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
    String? initialLiabilityAccountId,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<TransactionFormState?>,
              AsyncValue<TransactionFormState?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<TransactionFormState?>,
                AsyncValue<TransactionFormState?>
              >,
              AsyncValue<TransactionFormState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        editTransactionId: _$args.editTransactionId,
        initialMode: _$args.initialMode,
        initialFromAccountId: _$args.initialFromAccountId,
        initialToAccountId: _$args.initialToAccountId,
        initialLiabilityAccountId: _$args.initialLiabilityAccountId,
      ),
    );
  }
}
