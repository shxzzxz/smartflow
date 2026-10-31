import '../entity/amortization_plan.dart';

abstract interface class AmortizationRepository {
  Future<AmortizationPlan?> findById(String id);

  Future<List<AmortizationPlan>> findAll({String? deferralAccountId});

  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId});

  Future<void> save(AmortizationPlan plan);
}
