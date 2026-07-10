// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(billSummariesByAccount)
final billSummariesByAccountProvider = BillSummariesByAccountFamily._();

final class BillSummariesByAccountProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BillSummaryReadModel>>,
          List<BillSummaryReadModel>,
          FutureOr<List<BillSummaryReadModel>>
        >
    with
        $FutureModifier<List<BillSummaryReadModel>>,
        $FutureProvider<List<BillSummaryReadModel>> {
  BillSummariesByAccountProvider._({
    required BillSummariesByAccountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billSummariesByAccountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billSummariesByAccountHash();

  @override
  String toString() {
    return r'billSummariesByAccountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BillSummaryReadModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BillSummaryReadModel>> create(Ref ref) {
    final argument = this.argument as String;
    return billSummariesByAccount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BillSummariesByAccountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billSummariesByAccountHash() =>
    r'9b36caa7a8f417fb27afa726a4b8ee9c40fe517b';

final class BillSummariesByAccountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BillSummaryReadModel>>,
          String
        > {
  BillSummariesByAccountFamily._()
    : super(
        retry: null,
        name: r'billSummariesByAccountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillSummariesByAccountProvider call(String accountId) =>
      BillSummariesByAccountProvider._(argument: accountId, from: this);

  @override
  String toString() => r'billSummariesByAccountProvider';
}

@ProviderFor(billDetail)
final billDetailProvider = BillDetailFamily._();

final class BillDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<BillDetailReadModel?>,
          BillDetailReadModel?,
          FutureOr<BillDetailReadModel?>
        >
    with
        $FutureModifier<BillDetailReadModel?>,
        $FutureProvider<BillDetailReadModel?> {
  BillDetailProvider._({
    required BillDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billDetailHash();

  @override
  String toString() {
    return r'billDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BillDetailReadModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BillDetailReadModel?> create(Ref ref) {
    final argument = this.argument as String;
    return billDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BillDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billDetailHash() => r'1c2319db769b885953b93692e122f3969d5ad9cf';

final class BillDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BillDetailReadModel?>, String> {
  BillDetailFamily._()
    : super(
        retry: null,
        name: r'billDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BillDetailProvider call(String billId) =>
      BillDetailProvider._(argument: billId, from: this);

  @override
  String toString() => r'billDetailProvider';
}
