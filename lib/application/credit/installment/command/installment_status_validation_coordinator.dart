import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'installment_command.dart';

class InstallmentStatusValidationCoordinator {
  const InstallmentStatusValidationCoordinator({
    required InstallmentRepository installments,
    required BillRepository bills,
    required RepaymentRepository repayments,
  }) : _installments = installments,
       _bills = bills,
       _repayments = repayments;

  final InstallmentRepository _installments;
  final BillRepository _bills;
  final RepaymentRepository _repayments;

  Future<ContractStatusValidationResult> validate(String contractId) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final schedules = await _installments.listSchedules(contractId);
    if (schedules.isEmpty) {
      return const ContractStatusValidationResult(
        repairedScheduleCount: 0,
        contractStatusChanged: false,
        issues: [
          ContractStatusValidationIssue(
            type: ContractStatusValidationIssueType.noSchedules,
            message: '合同没有还款计划。',
          ),
        ],
      );
    }

    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    final issues = <ContractStatusValidationIssue>[];
    final blockedScheduleIds = <String>{};
    var hasBlockingIssues = false;
    final scheduleIds = schedules.map((schedule) => schedule.id).toSet();
    final allItemsById = <String, BillItem>{};
    final itemsBySchedule = <String, List<({String billId, BillItem item})>>{};

    for (final bill in bills) {
      for (final item in bill.items) {
        allItemsById[item.id] = item;
        final scheduleId = item.scheduleId;
        if (scheduleId != null && scheduleIds.contains(scheduleId)) {
          if (item.contractId != contract.id) {
            _addIssue(
              issues,
              ContractStatusValidationIssue(
                type:
                    ContractStatusValidationIssueType.billItemReferenceMismatch,
                message: '账单明细关联的合同与还款计划不一致。',
                scheduleId: scheduleId,
              ),
            );
            blockedScheduleIds.add(scheduleId);
            hasBlockingIssues = true;
            continue;
          }
          itemsBySchedule.putIfAbsent(scheduleId, () => []).add((
            billId: bill.id,
            item: item,
          ));
          continue;
        }
        if (item.contractId == contract.id) {
          _addIssue(
            issues,
            const ContractStatusValidationIssue(
              type: ContractStatusValidationIssueType.scheduleMissing,
              message: '账单明细关联的还款计划不存在。',
            ),
          );
          hasBlockingIssues = true;
        }
      }
    }

    for (final bill in bills) {
      final billRepayments = await _repayments.listByTarget(
        RepaymentTargetType.bill,
        bill.id,
      );
      for (final repayment in billRepayments) {
        for (final repaymentItem in repayment.items) {
          final billItemId = repaymentItem.billItemId;
          final billItem = billItemId == null ? null : allItemsById[billItemId];
          if (billItem == null) {
            _addIssue(
              issues,
              const ContractStatusValidationIssue(
                type: ContractStatusValidationIssueType.billItemMissing,
                message: '还款分摊关联的账单明细不存在。',
              ),
            );
            continue;
          }
          if (billItem.billId != bill.id) {
            final scheduleId = billItem.scheduleId;
            if (scheduleId != null && scheduleIds.contains(scheduleId)) {
              _addIssue(
                issues,
                ContractStatusValidationIssue(
                  type:
                      ContractStatusValidationIssueType.repaymentTargetMismatch,
                  message: '还款分摊关联的账单与还款目标不一致。',
                  scheduleId: scheduleId,
                ),
              );
              blockedScheduleIds.add(scheduleId);
              hasBlockingIssues = true;
            }
          }
        }
      }
    }

    final repaymentsById = <String, Repayment?>{};
    var repairedScheduleCount = 0;
    for (final schedule in schedules) {
      var allocated = RepaymentAmountBreakdown.zero;
      var hasAllocation = false;
      for (final entry
          in itemsBySchedule[schedule.id] ??
              const <({String billId, BillItem item})>[]) {
        final repaymentItems = await _repayments.listItemsByBillItem(
          entry.item.id,
        );
        for (final repaymentItem in repaymentItems) {
          var repayment = repaymentsById[repaymentItem.repaymentId];
          if (!repaymentsById.containsKey(repaymentItem.repaymentId)) {
            repayment = await _repayments.findRepayment(
              repaymentItem.repaymentId,
            );
            repaymentsById[repaymentItem.repaymentId] = repayment;
          }
          if (repayment == null) {
            _addIssue(
              issues,
              ContractStatusValidationIssue(
                type: ContractStatusValidationIssueType.repaymentMissing,
                message: '还款分摊找不到所属还款记录。',
                scheduleId: schedule.id,
              ),
            );
            blockedScheduleIds.add(schedule.id);
            hasBlockingIssues = true;
            continue;
          }
          if (repayment.targetType != RepaymentTargetType.bill ||
              repayment.targetId != entry.billId) {
            _addIssue(
              issues,
              ContractStatusValidationIssue(
                type: ContractStatusValidationIssueType.repaymentTargetMismatch,
                message: '还款分摊关联的账单与还款目标不一致。',
                scheduleId: schedule.id,
              ),
            );
            blockedScheduleIds.add(schedule.id);
            hasBlockingIssues = true;
            continue;
          }
          if (_isZeroAllocation(repaymentItem.allocated)) {
            _addIssue(
              issues,
              ContractStatusValidationIssue(
                type: ContractStatusValidationIssueType.zeroAllocation,
                message: '还款分摊金额全部为零。',
                scheduleId: schedule.id,
              ),
            );
            blockedScheduleIds.add(schedule.id);
            hasBlockingIssues = true;
            continue;
          }
          hasAllocation = true;
          allocated += repaymentItem.allocated;
        }
      }

      if (schedule.status == InstallmentScheduleStatus.skipped) {
        if (hasAllocation) {
          _addIssue(
            issues,
            ContractStatusValidationIssue(
              type:
                  ContractStatusValidationIssueType
                      .skippedScheduleHasAllocation,
              message: '已跳过的还款计划存在还款分摊。',
              scheduleId: schedule.id,
            ),
          );
          hasBlockingIssues = true;
        }
        continue;
      }
      if (blockedScheduleIds.contains(schedule.id)) {
        continue;
      }
      if (schedule.reconcileRepaymentStatus(
        allocatedPrincipalMinor: allocated.principal.minorUnits,
        hasAllocation: hasAllocation,
      )) {
        repairedScheduleCount++;
      }
    }

    final previousContractStatus = contract.status;
    if (!hasBlockingIssues) contract.refreshStatusFromSchedules(schedules);
    final contractStatusChanged = contract.status != previousContractStatus;
    if (repairedScheduleCount > 0 || contractStatusChanged) {
      await _installments.saveAggregate(contract, schedules);
    }
    return ContractStatusValidationResult(
      repairedScheduleCount: repairedScheduleCount,
      contractStatusChanged: contractStatusChanged,
      issues: issues,
    );
  }

  bool _isZeroAllocation(RepaymentAmountBreakdown allocated) {
    return allocated.principal.minorUnits == 0 &&
        allocated.interest.minorUnits == 0 &&
        allocated.fee.minorUnits == 0 &&
        allocated.discount.minorUnits == 0;
  }

  void _addIssue(
    List<ContractStatusValidationIssue> issues,
    ContractStatusValidationIssue issue,
  ) {
    final exists = issues.any(
      (current) =>
          current.type == issue.type && current.scheduleId == issue.scheduleId,
    );
    if (!exists) issues.add(issue);
  }
}
