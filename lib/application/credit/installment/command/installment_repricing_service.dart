import 'installment_plan_service.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import 'package:logging/logging.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/credit/entity/installment_contract.dart';
import '../../../../domain/credit/entity/installment_repricing.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/port/installment_repricing_repository.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../shared/transaction_runner.dart';
import '../../reference_rate/reference_rate_service.dart';

class RepricingScheduleDifference {
  const RepricingScheduleDifference({
    required this.scheduleId,
    required this.periodNo,
    required this.date,
    required this.oldPrincipal,
    required this.oldInterest,
    required this.principal,
    required this.interest,
  });
  final String scheduleId;
  final int periodNo;
  final DateTime date;
  final Money oldPrincipal, oldInterest, principal, interest;
}

class RepricingPreview {
  const RepricingPreview({
    required this.contractId,
    required this.recordId,
    required this.effectiveDate,
    required this.ratePpm,
    required this.token,
    required this.differences,
    required this.hasFrozenPeriods,
    required this.hasIssuedBills,
  });
  final String contractId, recordId, token;
  final DateTime effectiveDate;
  final int ratePpm;
  final List<RepricingScheduleDifference> differences;
  final bool hasFrozenPeriods, hasIssuedBills;
}

class InstallmentRepricingService {
  InstallmentRepricingService({
    required this.installments,
    required this.records,
    required this.referenceRates,
    required this.plans,
    required this.runner,
  });
  final InstallmentRepository installments;
  final InstallmentRepricingRepository records;
  final ReferenceRateService referenceRates;
  final InstallmentPlanService plans;
  final TransactionRunner runner;

  /// 补齐截至 now 已到重定价日的结果；参考利率严格早于重定价日。
  Future<bool> prepare(
    String contractId,
    DateTime now, {
    Map<(ReferenceRateType, DateTime), ReferenceRate?>? resolvedRates,
  }) async {
    final contract = await installments.findContract(contractId);
    if (contract == null ||
        contract.status != InstallmentContractStatus.active) {
      return true;
    }
    var complete = true;
    final existing = await records.list(contractId);
    final pending = _pendingResets(contract, existing, now);
    final resolved = resolvedRates ?? await _resolvePending(pending);
    for (final entry in pending) {
      final rule = entry.rule;
      final indices = entry.indices;
      final dates = indices.map(rule.resetDate).toList();
      final type = rule.referenceRateType;
      for (var index = 0; index < indices.length; index++) {
        final i = indices[index];
        final reset = dates[index];
        final rate = resolved[(type, _rateThrough(reset))];
        if (rate == null) {
          complete = false;
          break;
        }
        final change = RateChange(
          resetDate: reset,
          effectiveDate: rule.effectiveDate(i),
          referenceRate: rate,
          spreadBp: rule.spreadBp,
        );
        if (rate.type != type ||
            !referenceDate(rate.date).isBefore(reset) ||
            rate.ratePpm < 0 ||
            change.rate.ppm < 0) {
          throw BusinessException(
            CreditErrorCode.contractInvalidCommand,
            message: '参考利率不适用于本次重定价',
          );
        }
        await runner.run(() async {
          final current = await installments.findContract(contractId);
          if (current == null ||
              current.status != InstallmentContractStatus.active) {
            return;
          }
          final match = current.stageTerms.stages
              .where((s) => s.id == entry.stageId)
              .firstOrNull;
          if (match?.terms is! AmortizingStage ||
              (match!.terms as AmortizingStage).floatingRate != rule) {
            return;
          }
          await records.insert(
            InstallmentRepricing(
              id: '${entry.stageId}:${reset.toIso8601String()}',
              contractId: contractId,
              stageId: entry.stageId,
              change: change,
            ),
          );
        });
      }
    }
    return complete;
  }

  Future<RepricingPreview?> preview(String contractId) =>
      runner.run(() => _preview(contractId));

  Future<RepricingPreview?> preparePreview(
    String contractId,
    DateTime now,
  ) async {
    final complete = await prepare(contractId, now);
    final next = await preview(contractId);
    if (next == null && !complete) {
      throw BusinessException(
        ReferenceRateErrorCode.unavailable,
        message: '参考利率尚未确定，请稍后重试',
      );
    }
    return next;
  }

  Future<RepricingPreview?> _preview(String contractId) async {
    final contract = await installments.findContract(contractId);
    if (contract == null ||
        contract.status != InstallmentContractStatus.active) {
      return null;
    }
    final pending = (await records.list(
      contractId,
    )).where((r) => !r.applied).toList();
    if (pending.isEmpty) return null;
    final record = pending.first;
    final preview = await plans.previewChange(
      contractId,
      ApplyInstallmentRepricing(record),
    );
    final previous = {
      for (final row in preview.change.context.rows) row.id: row,
    };
    return RepricingPreview(
      contractId: contractId,
      recordId: record.id,
      effectiveDate: referenceDate(record.change.effectiveDate),
      ratePpm: record.change.rate.ppm,
      token: preview.token,
      hasFrozenPeriods: preview.hasFrozenPeriods,
      hasIssuedBills: preview.hasIssuedBills,
      differences: List.unmodifiable([
        for (final row in preview.change.updated)
          RepricingScheduleDifference(
            scheduleId: row.id!,
            periodNo: row.periodNo,
            date: row.date,
            oldPrincipal: previous[row.id]!.principal,
            oldInterest: previous[row.id]!.interest,
            principal: row.principal,
            interest: row.interest,
          ),
      ]),
    );
  }

  Future<void> apply(RepricingPreview preview) => runner.run(() async {
    final pending = (await records.list(
      preview.contractId,
    )).where((r) => !r.applied).toList();
    if (pending.isEmpty || pending.first.id != preview.recordId) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '重定价结果已变化，请重新预览',
      );
    }
    await plans.confirmChange(
      preview.contractId,
      ApplyInstallmentRepricing(pending.first),
      token: preview.token,
    );
    await records.markApplied(pending.first.id);
  });

  /// 确认用户已查看已应用结果；不重新计算计划，也不修改利率事实。
  Future<void> confirm(String contractId, Set<String> recordIds) => runner.run(
    () async {
      final current = {
        for (final record in await records.list(contractId)) record.id: record,
      };
      if (recordIds.any((id) => current[id]?.applied != true)) {
        throw BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '重定价记录已变化，请刷新后重试',
        );
      }
      await records.markUserConfirmed(contractId, recordIds);
    },
  );

  Future<({bool changed, bool needsRetry})> runDue(DateTime now) async {
    var changed = false;
    var needsRetry = false;
    final ids = await records.activeContractIds();
    final eligibleIds = <String>[];
    final pending = <_PendingReset>[];
    for (final id in ids) {
      try {
        final contract = await installments.findContract(id);
        if (contract == null ||
            contract.status != InstallmentContractStatus.active) {
          continue;
        }
        final existing = await records.list(id);
        pending.addAll(_pendingResets(contract, existing, now));
        eligibleIds.add(id);
      } on Exception catch (error, stack) {
        needsRetry = true;
        _logFailure(error, stack);
      }
    }
    final resolved = await _resolvePending(pending);
    for (final id in eligibleIds) {
      try {
        if (!await prepare(id, now, resolvedRates: resolved)) needsRetry = true;
        while (true) {
          final next = await preview(id);
          if (next == null) break;
          await apply(next);
          changed = true;
        }
      } on Exception catch (error, stack) {
        needsRetry = true;
        _logFailure(error, stack);
      }
    }
    return (changed: changed, needsRetry: needsRetry);
  }

  void _logFailure(Exception error, StackTrace stack) {
    Logger('application.credit.repricing').log(
      error is BusinessException ? Level.WARNING : Level.SEVERE,
      'Loan repricing failed; it will retry after its cooldown.',
      error,
      stack,
    );
  }

  List<_PendingReset> _pendingResets(
    InstallmentContract contract,
    List<InstallmentRepricing> existing,
    DateTime now,
  ) {
    final pending = <_PendingReset>[];
    for (final stage in contract.stageTerms.stages) {
      if (stage.terms is! AmortizingStage) continue;
      final terms = stage.terms as AmortizingStage;
      final rule = terms.floatingRate;
      if (rule == null) continue;
      terms.validateFloatingRate();
      final end = referenceDate(terms.dates.getDates().last);
      final indices = <int>[];
      for (
        var i = 0;
        !rule.resetDate(i).isAfter(referenceDate(now)) &&
            rule.effectiveDate(i).isBefore(end);
        i++
      ) {
        if (!existing.any(
          (record) =>
              record.stageId == stage.id &&
              referenceDate(record.change.resetDate) == rule.resetDate(i),
        )) {
          indices.add(i);
        }
      }
      if (indices.isNotEmpty) {
        pending.add(_PendingReset(stage.id, rule, indices));
      }
    }
    return pending;
  }

  Future<Map<(ReferenceRateType, DateTime), ReferenceRate?>> _resolvePending(
    List<_PendingReset> pending,
  ) async {
    final types = {for (final entry in pending) entry.rule.referenceRateType};
    final dates = {
      for (final entry in pending)
        for (final index in entry.indices)
          _rateThrough(entry.rule.resetDate(index)),
    };
    final results = await referenceRates.resolveMany(
      types.toList(),
      dates.toList(),
    );
    return {
      for (final entry in results.entries)
        for (final result in entry.value) (entry.key, result.date): result.rate,
    };
  }

  DateTime _rateThrough(DateTime reset) =>
      referenceDate(reset).subtract(const Duration(days: 1));
}

class _PendingReset {
  _PendingReset(this.stageId, this.rule, this.indices);
  final String stageId;
  final FloatingRateRule rule;
  final List<int> indices;
}
