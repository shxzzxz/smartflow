import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/port/amortization_repository.dart';

class AmortizationPlanQueryService {
  const AmortizationPlanQueryService(this._repository);

  final AmortizationRepository _repository;

  Future<AmortizationPlan?> findById(String id) => _repository.findById(id);

  Future<List<AmortizationPlan>> findAll({String? deferralAccountId}) =>
      _repository.findAll(deferralAccountId: deferralAccountId);

  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId}) =>
      _repository.watchAll(deferralAccountId: deferralAccountId);

  Stream<AmortizationPlan?> watchById(String id) =>
      watchAll().map((plans) => plans.where((plan) => plan.id == id).firstOrNull);
}
