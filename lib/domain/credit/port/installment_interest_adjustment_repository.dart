import '../entity/installment_interest_adjustment.dart';

abstract interface class InstallmentInterestAdjustmentRepository {
  Future<void> save(InstallmentInterestAdjustment record);
  Future<void> delete(String contractId, String id);
}
