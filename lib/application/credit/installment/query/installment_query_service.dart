import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_repayment.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

abstract interface class InstallmentQueryService {
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  );

  Future<InstallmentContract?> findContract(String contractId);

  Future<List<InstallmentSchedule>> listSchedules(String contractId);

  Future<List<InstallmentRepayment>> listRepayments(String contractId);

  /// 该负债账户上所有 active 分期合同的未还本金合计（minor units）。
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId);

  /// 反查交易是否被分期模块持有。
  /// 命中放款侧返回 disbursement；命中还款侧返回 repayment；否则 null。
  Future<InstallmentLink?> findLinkByTransaction(String transactionId);
}

/// 分期模块对某 transaction 的所有权指针。
sealed class InstallmentLink {
  const InstallmentLink({required this.contractId});

  final String contractId;
}

class InstallmentDisbursementLink extends InstallmentLink {
  const InstallmentDisbursementLink({required super.contractId});
}

class InstallmentRepaymentLink extends InstallmentLink {
  const InstallmentRepaymentLink({
    required super.contractId,
    required this.repaymentType,
  });

  final InstallmentRepaymentType repaymentType;
}

class InstallmentQueryServiceImpl implements InstallmentQueryService {
  const InstallmentQueryServiceImpl({
    required InstallmentRepository repository,
    required TransactionQueryService transactionQueryService,
  }) : _repository = repository,
       _transactionQueryService = transactionQueryService;

  final InstallmentRepository _repository;
  final TransactionQueryService _transactionQueryService;

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) {
    return _repository.listContractsByLiabilityAccount(liabilityAccountId);
  }

  @override
  Future<InstallmentContract?> findContract(String contractId) {
    return _repository.findContract(contractId);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) {
    return _repository.listSchedules(contractId);
  }

  @override
  Future<List<InstallmentRepayment>> listRepayments(String contractId) {
    return _repository.listRepayments(contractId);
  }

  @override
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId) async {
    final contracts = await _repository.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    var sum = 0;
    for (final contract in contracts) {
      if (contract.status != InstallmentContractStatus.active) continue;
      final paid = await _paidPrincipalForContract(contract.id);
      final unpaid = contract.principal.minorUnits - paid;
      if (unpaid > 0) sum += unpaid;
    }
    return sum;
  }

  @override
  Future<InstallmentLink?> findLinkByTransaction(String transactionId) async {
    final repayment = await _repository.findRepaymentByTransaction(
      transactionId,
    );
    if (repayment != null) {
      return InstallmentRepaymentLink(
        contractId: repayment.contractId,
        repaymentType: repayment.repaymentType,
      );
    }
    final contract = await _repository.findContractByDisbursementTransaction(
      transactionId,
    );
    if (contract != null) {
      return InstallmentDisbursementLink(contractId: contract.id);
    }
    return null;
  }

  Future<int> _paidPrincipalForContract(String contractId) async {
    final repayments = await _repository.listRepayments(contractId);
    return _transactionQueryService.getDetailAmountSum(
      transactionIds: repayments.map((r) => r.transactionId),
      detailType: TransactionDetailType.repaymentPrincipal,
    );
  }
}
