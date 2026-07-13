import '../../../../core/money/money.dart';
import '../../../../domain/credit/port/credit_ledger_port.dart';
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
  const ContractRepaymentQueryImpl({
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
  }) : _repayments = repayments,
       _ledger = ledger;

  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;

  @override
  Future<List<ContractRepayment>> listContractRepayments(
    String contractId,
  ) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    final result = <ContractRepayment>[];
    for (final repayment in repayments) {
      final transaction =
          repayment.rootTransactionId == null
              ? null
              : await _ledger.findCurrentParentTransactionByRoot(
                repayment.rootTransactionId!,
              );
      final allocated = repayment.totalAllocated();
      result.add(
        ContractRepayment(
          id: repayment.id,
          transactionId: repayment.rootTransactionId,
          repaymentType: repayment.repaymentType,
          occurredAt:
              transaction?.occurredAt ??
              repayment.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0),
          principal: allocated.principal,
          interest: allocated.interest,
          fee: allocated.fee,
        ),
      );
    }
    return result;
  }
}
