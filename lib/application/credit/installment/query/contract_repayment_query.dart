import '../../../../core/money/money.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';

class ContractRepayment {
  const ContractRepayment({
    required this.id,
    required this.repaymentType,
    required this.occurredAt,
    required this.principal,
    required this.interest,
    required this.fee,
    this.transactionId,
  });

  final String id;
  final String? transactionId;
  final RepaymentType repaymentType;
  final DateTime occurredAt;
  final Money principal;
  final Money interest;
  final Money fee;
}

abstract interface class ContractRepaymentQuery {
  Future<List<ContractRepayment>> listContractRepayments(String contractId);
}

class ContractRepaymentQueryImpl implements ContractRepaymentQuery {
  const ContractRepaymentQueryImpl({required RepaymentRepository repayments})
    : _repayments = repayments;

  final RepaymentRepository _repayments;

  @override
  Future<List<ContractRepayment>> listContractRepayments(
    String contractId,
  ) async {
    final repayments = await _repayments.listByContract(contractId);
    final result = <ContractRepayment>[];
    for (final repayment in repayments) {
      final allocated = repayment.totalAllocated();
      result.add(
        ContractRepayment(
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
    return result;
  }
}
