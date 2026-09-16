import '../installment/command/installment_repricing_app_service.dart';

class InstallmentRepricingTaskCoordinator {
  const InstallmentRepricingTaskCoordinator(this._service);

  final InstallmentRepricingAppService _service;

  Future<({bool changed, bool needsRetry})> runDue(DateTime now) =>
      _service.runDue(now);
}
