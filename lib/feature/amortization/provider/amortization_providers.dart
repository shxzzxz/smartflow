import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/orchestration/orchestration_command_api.dart';

part 'amortization_providers.g.dart';

@riverpod
Stream<List<AmortizationPlan>> amortizationPlans(
  Ref ref, {
  String? deferralAccountId,
}) {
  return ref
      .watch(amortizationPlanQueryServiceProvider)
      .watchAll(deferralAccountId: deferralAccountId);
}

@riverpod
Stream<AmortizationPlan?> amortizationPlan(Ref ref, String planId) {
  return ref.watch(amortizationPlanQueryServiceProvider).watchById(planId);
}
