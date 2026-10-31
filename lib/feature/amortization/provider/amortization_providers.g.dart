// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amortization_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(amortizationPlans)
final amortizationPlansProvider = AmortizationPlansFamily._();

final class AmortizationPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AmortizationPlan>>,
          List<AmortizationPlan>,
          Stream<List<AmortizationPlan>>
        >
    with
        $FutureModifier<List<AmortizationPlan>>,
        $StreamProvider<List<AmortizationPlan>> {
  AmortizationPlansProvider._({
    required AmortizationPlansFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'amortizationPlansProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$amortizationPlansHash();

  @override
  String toString() {
    return r'amortizationPlansProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<AmortizationPlan>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AmortizationPlan>> create(Ref ref) {
    final argument = this.argument as String?;
    return amortizationPlans(ref, deferralAccountId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AmortizationPlansProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$amortizationPlansHash() => r'e6b2f6f90ac5b8d01603f1dfc6f22692bcecd59c';

final class AmortizationPlansFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<AmortizationPlan>>, String?> {
  AmortizationPlansFamily._()
    : super(
        retry: null,
        name: r'amortizationPlansProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AmortizationPlansProvider call({String? deferralAccountId}) =>
      AmortizationPlansProvider._(argument: deferralAccountId, from: this);

  @override
  String toString() => r'amortizationPlansProvider';
}

@ProviderFor(amortizationPlan)
final amortizationPlanProvider = AmortizationPlanFamily._();

final class AmortizationPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<AmortizationPlan?>,
          AmortizationPlan?,
          Stream<AmortizationPlan?>
        >
    with
        $FutureModifier<AmortizationPlan?>,
        $StreamProvider<AmortizationPlan?> {
  AmortizationPlanProvider._({
    required AmortizationPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'amortizationPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$amortizationPlanHash();

  @override
  String toString() {
    return r'amortizationPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AmortizationPlan?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AmortizationPlan?> create(Ref ref) {
    final argument = this.argument as String;
    return amortizationPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AmortizationPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$amortizationPlanHash() => r'efa2d25a681a0efd471eb8ebe1b51255e4d02893';

final class AmortizationPlanFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AmortizationPlan?>, String> {
  AmortizationPlanFamily._()
    : super(
        retry: null,
        name: r'amortizationPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AmortizationPlanProvider call(String planId) =>
      AmortizationPlanProvider._(argument: planId, from: this);

  @override
  String toString() => r'amortizationPlanProvider';
}
