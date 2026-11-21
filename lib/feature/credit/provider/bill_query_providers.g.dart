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
    r'2ba223975e74d93d7e41932fc061be21cc872556';

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

@ProviderFor(accountBillPreview)
final accountBillPreviewProvider = AccountBillPreviewFamily._();

final class AccountBillPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BillSummaryReadModel>>,
          List<BillSummaryReadModel>,
          FutureOr<List<BillSummaryReadModel>>
        >
    with
        $FutureModifier<List<BillSummaryReadModel>>,
        $FutureProvider<List<BillSummaryReadModel>> {
  AccountBillPreviewProvider._({
    required AccountBillPreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountBillPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountBillPreviewHash();

  @override
  String toString() {
    return r'accountBillPreviewProvider'
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
    return accountBillPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountBillPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountBillPreviewHash() =>
    r'1335e364bc24bec421fea9fb7ac959512a6e8a39';

final class AccountBillPreviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BillSummaryReadModel>>,
          String
        > {
  AccountBillPreviewFamily._()
    : super(
        retry: null,
        name: r'accountBillPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountBillPreviewProvider call(String accountId) =>
      AccountBillPreviewProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountBillPreviewProvider';
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
