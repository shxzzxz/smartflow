// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credit_account_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(creditAccountOverview)
final creditAccountOverviewProvider = CreditAccountOverviewFamily._();

final class CreditAccountOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<CreditAccountOverviewReadModel?>,
          CreditAccountOverviewReadModel?,
          FutureOr<CreditAccountOverviewReadModel?>
        >
    with
        $FutureModifier<CreditAccountOverviewReadModel?>,
        $FutureProvider<CreditAccountOverviewReadModel?> {
  CreditAccountOverviewProvider._({
    required CreditAccountOverviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'creditAccountOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$creditAccountOverviewHash();

  @override
  String toString() {
    return r'creditAccountOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CreditAccountOverviewReadModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CreditAccountOverviewReadModel?> create(Ref ref) {
    final argument = this.argument as String;
    return creditAccountOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CreditAccountOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$creditAccountOverviewHash() =>
    r'264c9c387fc384043fb532db0bc2598651e17fa2';

final class CreditAccountOverviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CreditAccountOverviewReadModel?>,
          String
        > {
  CreditAccountOverviewFamily._()
    : super(
        retry: null,
        name: r'creditAccountOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CreditAccountOverviewProvider call(String accountId) =>
      CreditAccountOverviewProvider._(argument: accountId, from: this);

  @override
  String toString() => r'creditAccountOverviewProvider';
}
