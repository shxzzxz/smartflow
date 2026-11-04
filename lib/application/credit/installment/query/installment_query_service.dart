import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_repayment_progress_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_transaction_fact_policy.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_role.dart';

import 'installment_dtos.dart';
import 'port/installment_progress_source.dart';
import 'port/installment_statistics_change_source.dart';

abstract interface class InstallmentQueryService {
  /// 分期基本信息与当前履约进度，不返回完整还款计划。
  Future<List<InstallmentDTO>> listInstallmentsByLiabilityAccount(
    String liabilityAccountId,
  );

  /// 单条分期查询，不返回完整还款计划。
  Future<InstallmentDTO?> findInstallment(String installmentId);

  /// 批量加载业务活动摘要所需的单条分期查询。
  Future<Map<String, InstallmentDTO>> findInstallments(
    Set<String> installmentIds,
  );

  Stream<InstallmentDTO?> watchInstallment(String installmentId);

  /// Classifies one or more transactions that belong to installment contracts.
  Future<Map<String, InstallmentBusinessActivityItemProjection>>
  findBusinessActivityItems(
    Map<String, InstallmentBusinessActivityItemRequest> requests,
  );

  /// 分期基本信息与完整还款计划。
  Future<InstallmentDetailDTO?> findInstallmentDetail(String installmentId);

  /// 重定价配置与已应用记录。
  Future<InstallmentRepricingDTO?> findInstallmentRepricing(
    String installmentId,
  );

  /// 合同级利息调整记录。
  Future<InstallmentInterestAdjustmentDTO?> findInstallmentInterestAdjustment(
    String installmentId,
  );
}

class InstallmentQueryServiceImpl implements InstallmentQueryService {
  const InstallmentQueryServiceImpl({
    required InstallmentRepository repository,
    required InstallmentProgressSource progress,
    required InstallmentStatisticsChangeSource changes,
    CreditLedgerPort? ledger,
    InstallmentRepaymentProgressService repaymentProgress =
        const InstallmentRepaymentProgressService(),
  }) : _repository = repository,
       _progress = progress,
       _changes = changes,
       _ledger = ledger,
       _repaymentProgress = repaymentProgress;

  final InstallmentRepository _repository;
  final InstallmentProgressSource _progress;
  final InstallmentStatisticsChangeSource _changes;
  final CreditLedgerPort? _ledger;
  final InstallmentRepaymentProgressService _repaymentProgress;

  @override
  Future<List<InstallmentDTO>> listInstallmentsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final contracts = await _repository.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    return _loadInstallments(contracts);
  }

  @override
  Future<InstallmentDTO?> findInstallment(String installmentId) async {
    final contract = await _repository.findContract(installmentId);
    if (contract == null) return null;
    final loaded = await _loadInstallments([contract]);
    return loaded.single;
  }

  @override
  Future<Map<String, InstallmentDTO>> findInstallments(
    Set<String> installmentIds,
  ) async {
    if (installmentIds.isEmpty) return const {};
    final contracts = await Future.wait(
      installmentIds.map(_repository.findContract),
    );
    final values = await _loadInstallments(
      contracts.whereType<InstallmentContract>(),
    );
    return {for (final value in values) value.id: value};
  }

  @override
  Stream<InstallmentDTO?> watchInstallment(String installmentId) {
    return _changes.watchChanges().asyncMap(
      (_) => findInstallment(installmentId),
    );
  }

  @override
  Future<Map<String, InstallmentBusinessActivityItemProjection>>
  findBusinessActivityItems(
    Map<String, InstallmentBusinessActivityItemRequest> requests,
  ) async {
    if (requests.isEmpty) return const {};
    final installments = await findInstallments({
      for (final request in requests.values) request.installmentId,
    });
    final items = <String, InstallmentBusinessActivityItemProjection>{};
    for (final entry in requests.entries) {
      final installment = installments[entry.value.installmentId];
      if (installment == null) continue;
      final factKind = resolveInstallmentTransactionFactKind(
        installmentType: installment.installmentType,
        businessPurpose: entry.value.businessPurpose,
      );
      if (factKind == null) continue;
      final isOrigin =
          factKind == InstallmentTransactionFactKind.purchase ||
          factKind == InstallmentTransactionFactKind.disbursement;
      items[entry.key] = InstallmentBusinessActivityItemProjection(
        transactionId: entry.key,
        installmentId: installment.id,
        installmentType: installment.installmentType,
        factKind: factKind,
        role: isOrigin
            ? BusinessActivityItemRole.origin
            : BusinessActivityItemRole.followUp,
      );
    }
    return items;
  }

  @override
  Future<InstallmentDetailDTO?> findInstallmentDetail(
    String installmentId,
  ) async {
    final contract = await _repository.findContract(installmentId);
    if (contract == null) return null;
    final installment = (await _loadInstallments([contract])).single;
    return InstallmentDetailDTO(
      installment: installment,
      schedules: contract.schedules.map(_scheduleDTO),
    );
  }

  @override
  Future<InstallmentRepricingDTO?> findInstallmentRepricing(
    String installmentId,
  ) async {
    final contract = await _repository.findContract(installmentId);
    if (contract == null) return null;
    return InstallmentRepricingDTO(
      installmentId: contract.id,
      configurations: [
        for (final configuration in contract.repricingConfigurations)
          InstallmentRepricingConfigurationDTO(
            id: configuration.id,
            stageId: configuration.stageId,
            effectiveFrom: configuration.effectiveFrom,
            rule: configuration.rule,
            lastGeneratedDate: configuration.lastGeneratedDate,
            generationCompleted: configuration.generationCompleted,
          ),
      ],
      records: [
        for (final record in contract.repricings)
          InstallmentRepricingRecordDTO(
            id: record.id,
            stageId: record.stageId,
            change: record.change,
            status: record.status,
          ),
      ],
    );
  }

  @override
  Future<InstallmentInterestAdjustmentDTO?> findInstallmentInterestAdjustment(
    String installmentId,
  ) async {
    final contract = await _repository.findContract(installmentId);
    if (contract == null) return null;
    return InstallmentInterestAdjustmentDTO(
      installmentId: contract.id,
      adjustments: [
        for (final record in contract.interestAdjustments)
          InstallmentInterestAdjustmentItemDTO(
            id: record.id,
            adjustment: record.adjustment,
          ),
      ],
    );
  }

  Future<List<InstallmentDTO>> _loadInstallments(
    Iterable<InstallmentContract> contracts,
  ) async {
    final values = contracts.toList();
    if (values.isEmpty) return const [];
    final factsByContract = await _progress.findRepaymentFacts({
      for (final contract in values) contract.id,
    });
    return Future.wait([
      for (final contract in values)
        _mapInstallment(
          contract,
          repaymentFacts: factsByContract[contract.id] ?? const [],
        ),
    ]);
  }

  Future<InstallmentDTO> _mapInstallment(
    InstallmentContract contract, {
    required List<InstallmentRepaymentAllocationFact> repaymentFacts,
  }) async {
    final scheduleIds = {
      for (final schedule in contract.schedules) schedule.id,
    };
    final allocatedByScheduleId = <String, RepaymentAmountBreakdown>{};
    for (final fact in repaymentFacts) {
      final scheduleId = fact.scheduleId;
      if (scheduleId == null || !scheduleIds.contains(scheduleId)) continue;
      allocatedByScheduleId[scheduleId] =
          (allocatedByScheduleId[scheduleId] ?? RepaymentAmountBreakdown.zero) +
          fact.allocated;
    }
    final progress = _repaymentProgress.project(
      installment: contract,
      allocatedByScheduleId: allocatedByScheduleId,
      repayments: repaymentFacts.map((fact) => fact.allocated),
    );
    final sourceTransaction =
        contract.installmentType == InstallmentType.disbursement &&
            contract.sourceRefId != null
        ? await _ledger?.findParentTransaction(contract.sourceRefId!)
        : null;
    return InstallmentDTO(
      id: contract.id,
      name: contract.name,
      liabilityAccountId: contract.liabilityAccountId,
      installmentType: contract.installmentType,
      sourceRefId: contract.sourceRefId,
      disbursementAccountId: sourceTransaction?.settlementInAccountId,
      principal: contract.principal,
      borrowingDate: contract.borrowingDate,
      status: contract.status,
      note: contract.note,
      createdAt: contract.createdAt,
      stageTerms: contract.stageTerms,
      repaymentProgress: InstallmentRepaymentProgressDTO(
        paidPeriodCount: progress.paidPeriodCount,
        totalPeriodCount: progress.totalPeriodCount,
        remainingPrincipal: progress.remainingPrincipal,
        repaid: progress.repaid,
      ),
    );
  }

  InstallmentScheduleDTO _scheduleDTO(InstallmentSchedule schedule) {
    return InstallmentScheduleDTO(
      id: schedule.id,
      contractId: schedule.contractId,
      stageId: schedule.stageId,
      periodNo: schedule.periodNo,
      expectedRepaymentDate: schedule.expectedRepaymentDate,
      expectedPrincipal: schedule.expectedPrincipal,
      expectedInterest: schedule.expectedInterest,
      expectedFee: schedule.expectedFee,
      status: schedule.status,
      note: schedule.note,
      createdAt: schedule.createdAt,
    );
  }
}
