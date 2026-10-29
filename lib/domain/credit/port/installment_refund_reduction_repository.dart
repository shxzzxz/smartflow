import '../entity/installment_refund_reduction.dart';

abstract interface class InstallmentRefundReductionRepository {
  Future<List<InstallmentRefundReduction>> listByContract(String contractId);

  Future<InstallmentRefundReduction?> findByRefundTransaction(
    String refundTransactionId,
  );

  Future<void> save(InstallmentRefundReduction reduction);

  Future<void> deleteByRefundTransaction(String refundTransactionId);

  Future<void> deleteByContract(String contractId);
}
