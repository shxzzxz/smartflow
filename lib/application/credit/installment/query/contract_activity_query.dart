import '../../../../core/money/money.dart';
import '../../../../domain/credit/port/installment_refund_reduction_repository.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';

sealed class ContractActivity {
  const ContractActivity({required this.id, required this.occurredAt});

  final String id;
  final DateTime occurredAt;

  String? get transactionId;
}

class ContractRepaymentActivity extends ContractActivity {
  const ContractRepaymentActivity({
    required super.id,
    required super.occurredAt,
    required this.repaymentType,
    required this.principal,
    required this.interest,
    required this.fee,
    this.transactionId,
  });

  final RepaymentType repaymentType;
  final Money principal;
  final Money interest;
  final Money fee;

  @override
  final String? transactionId;
}

class ContractRefundReductionActivity extends ContractActivity {
  const ContractRefundReductionActivity({
    required super.id,
    required super.occurredAt,
    required this.principal,
    required this.refundTransactionId,
  });

  final Money principal;
  final String refundTransactionId;

  @override
  String? get transactionId => refundTransactionId;
}

abstract interface class ContractActivityQuery {
  Future<List<ContractActivity>> listContractActivities(String contractId);
}

class ContractActivityQueryImpl implements ContractActivityQuery {
  const ContractActivityQueryImpl({
    required RepaymentRepository repayments,
    required InstallmentRefundReductionRepository refundReductions,
  }) : _repayments = repayments,
       _refundReductions = refundReductions;

  final RepaymentRepository _repayments;
  final InstallmentRefundReductionRepository _refundReductions;

  @override
  Future<List<ContractActivity>> listContractActivities(
    String contractId,
  ) async {
    final repayments = await _repayments.listByContract(contractId);
    final refundReductions = await _refundReductions.listByContract(contractId);
    final result = <ContractActivity>[];
    for (final repayment in repayments) {
      final allocated = repayment.totalAllocated();
      result.add(
        ContractRepaymentActivity(
          id: repayment.id,
          transactionId: repayment.transactionId,
          repaymentType: repayment.repaymentType,
          occurredAt: repayment.repaymentDate,
          principal: allocated.principal,
          interest: allocated.interest,
          fee: allocated.fee,
        ),
      );
    }
    for (final reduction in refundReductions) {
      result.add(
        ContractRefundReductionActivity(
          id: reduction.id,
          occurredAt: reduction.occurredAt,
          principal: reduction.principal,
          refundTransactionId: reduction.refundTransactionId,
        ),
      );
    }
    result.sort(_compareActivities);
    return result;
  }
}

int _compareActivities(ContractActivity left, ContractActivity right) {
  final byOccurredAt = right.occurredAt.compareTo(left.occurredAt);
  if (byOccurredAt != 0) return byOccurredAt;
  return right.id.compareTo(left.id);
}
