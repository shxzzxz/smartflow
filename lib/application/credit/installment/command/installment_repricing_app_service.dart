import 'package:logging/logging.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../domain/credit/entity/installment_contract.dart';
import '../../../../domain/credit/entity/installment_repricing.dart';
import '../../../../domain/credit/entity/installment_repricing_configuration.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../port/installment_plan_change_port.dart';
import '../../../../domain/credit/port/installment_repricing_repository.dart';
import '../../../../domain/credit/service/installment/installment_repricing_planner.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../shared/transaction_runner.dart';
import '../../reference_rate/reference_rate_app_service.dart';

class InstallmentRepricingAppService {
  InstallmentRepricingAppService({
    required this.installments,
    required this.records,
    required this.referenceRates,
    required this.plans,
    required this.runner,
  });
  final InstallmentRepository installments;
  final InstallmentRepricingRepository records;
  final ReferenceRateAppService referenceRates;
  final InstallmentPlanChangePort plans;
  final TransactionRunner runner;

  Future<void> addConfiguration(
    String contractId, {
    required String stageId,
    required DateTime effectiveFrom,
    required FloatingRateRule rule,
  }) => runner.run(() async {
    final contract = await _requireContract(contractId);
    contract.stageTerms.repaymentRange(stageId, contract.borrowingDate);
    final configuration = InstallmentRepricingConfiguration(
      id: '$contractId:$stageId:configuration:${referenceDate(effectiveFrom).toIso8601String()}',
      contractId: contractId,
      stageId: stageId,
      effectiveFrom: referenceDate(effectiveFrom),
      rule: rule,
    );
    configuration.validate();
    await records.insertConfiguration(configuration);
    await _completeGeneration(contractId);
  });

  Future<void> deleteConfiguration(String contractId, String configurationId) =>
      runner.run(() async {
        final contract = await _requireContract(contractId);
        final configuration = contract.repricingConfigurations
            .where((value) => value.id == configurationId)
            .firstOrNull;
        if (configuration == null) _invalid('重定价配置已不存在');
        await records.deleteConfiguration(configuration);
        // 后续配置删除后，前一配置可能重新拥有尚未处理的周期。
        for (final previous in contract.repricingConfigurations) {
          if (previous.stageId == configuration.stageId &&
              previous.generationCompleted &&
              previous.effectiveFrom.isBefore(configuration.effectiveFrom)) {
            await records.updateGenerationState(
              previous.withGenerationCompleted(false),
            );
          }
        }
        await _completeGeneration(contractId);
      });

  Future<void> create(
    String contractId, {
    required String stageId,
    required DateTime resetDate,
    required DateTime effectiveDate,
    required InterestRateType referenceRateType,
    required int spreadBp,
  }) async {
    final contract = await _requireContract(contractId);
    final reset = referenceDate(resetDate),
        effective = referenceDate(effectiveDate);
    _validateDates(contract, stageId, reset, effective);
    if (contract.repricings.any(
      (record) =>
          record.stageId == stageId &&
          referenceDate(record.change.effectiveDate) == effective,
    )) {
      _invalid('该阶段的重定价生效日已有记录');
    }
    final referenceRate = (await referenceRates.resolveOne(
      referenceRateType,
      _rateThrough(reset),
    )).rate;
    if (referenceRate == null) _invalid('重定价所需参考利率暂不可用，请稍后重试');
    final change = RateChange(
      resetDate: reset,
      effectiveDate: effective,
      referenceRate: referenceRate,
      spreadBp: spreadBp,
    );
    change.validate();
    if (referenceRate.type != referenceRateType ||
        !referenceDate(referenceRate.date).isBefore(reset)) {
      _invalid('参考利率须属于所选类型且严格早于重定价日');
    }
    await runner.run(() async {
      final current = await _requireContract(contractId);
      _validateDates(current, stageId, reset, effective);
      final record = InstallmentRepricing(
        id: '$contractId:$stageId:rate:${effective.toIso8601String()}',
        contractId: contractId,
        stageId: stageId,
        change: change,
      );
      if (!await records.insert(record)) _invalid('该阶段的重定价生效日已有记录');
      await _applyPending(contractId);
    });
  }

  Future<void> delete(String contractId, String recordId) =>
      runner.run(() async {
        final contract = await _requireContract(contractId);
        final record = contract.repricings
            .where((record) => record.id == recordId)
            .firstOrNull;
        if (record == null) _invalid('重定价记录已不存在');
        await records.delete(record);
        await plans.applyAutomaticChange(
          contractId,
          const RecalculateFromOperations(),
        );
      });

  /// 网络取值在事务外；落库时重新核对配置归属、同日唯一性和生成进度。
  Future<bool> prepare(
    String contractId,
    DateTime now, {
    Map<(InterestRateType, DateTime), ReferenceRate?>? resolvedRates,
  }) async {
    final contract = await installments.findContract(contractId);
    if (contract == null) return true;
    final pending = _pending(contract, now);
    final existingDates = {
      for (final record in contract.repricings)
        (record.stageId, referenceDate(record.change.effectiveDate)),
    };
    final resolved =
        resolvedRates ??
        await _resolvePending([
          for (final candidate in pending)
            if (!existingDates.contains((
              candidate.configuration.stageId,
              candidate.effectiveDate,
            )))
              candidate,
        ]);
    var complete = true;
    final blockedConfigurations = <String>{};
    for (final candidate in pending) {
      if (blockedConfigurations.contains(candidate.configuration.id)) continue;
      final referenceRate =
          resolved[(
            candidate.configuration.rule.referenceRateType,
            _rateThrough(candidate.resetDate),
          )];
      final processed = await runner.run(() async {
        final current = await installments.findContract(contractId);
        if (current == null) return true;
        final stillDue = _pending(current, now).any(
          (value) =>
              value.effectiveDate == candidate.effectiveDate &&
              value.resetDate == candidate.resetDate &&
              value.configuration.id == candidate.configuration.id &&
              value.configuration.stageId == candidate.configuration.stageId &&
              value.configuration.rule == candidate.configuration.rule,
        );
        if (!stillDue) return true;
        if (!current.repricings.any(
          (record) =>
              record.stageId == candidate.configuration.stageId &&
              referenceDate(record.change.effectiveDate) ==
                  candidate.effectiveDate,
        )) {
          if (referenceRate == null) return false;
          await records.insert(
            InstallmentRepricing(
              id: '$contractId:${candidate.configuration.stageId}:rate:${candidate.effectiveDate.toIso8601String()}',
              contractId: contractId,
              stageId: candidate.configuration.stageId,
              change: _change(candidate, referenceRate),
            ),
          );
        }
        await records.advanceGeneration(
          candidate.configuration.id,
          candidate.resetDate,
        );
        await _completeGeneration(contractId);
        return true;
      });
      if (!processed) {
        complete = false;
        blockedConfigurations.add(candidate.configuration.id);
      }
    }
    await runner.run(() => _completeGeneration(contractId));
    return complete;
  }

  Future<void> _completeGeneration(String contractId) async {
    final contract = await installments.findContract(contractId);
    if (contract == null) return;
    final completed = const InstallmentRepricingPlanner().completed(
      configurations: contract.repricingConfigurations,
      borrowingDate: contract.borrowingDate,
      terms: contract.stageTerms,
    );
    for (final configuration in completed) {
      await records.updateGenerationState(configuration);
    }
  }

  Future<bool> _applyPending(String contractId) => runner.run(() async {
    final pending = (await records.list(
      contractId,
    )).where((record) => !record.applied).toList();
    if (pending.isEmpty) return false;
    await plans.applyAutomaticChange(
      contractId,
      const RecalculateFromOperations(),
    );
    for (final record in pending) {
      record.markApplied();
      await records.update(record);
    }
    return true;
  });

  /// 确认仅改变提示状态；每次计划计算仍消费所有有效利率事实。
  Future<void> confirm(String contractId, Set<String> recordIds) => runner.run(
    () async {
      final current = {
        for (final record in await records.list(contractId)) record.id: record,
      };
      if (recordIds.any((id) => current[id]?.contractId != contractId)) {
        throw BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '重定价记录已变化，请刷新后重试',
        );
      }
      for (final id in recordIds) {
        current[id]!.confirm();
        await records.update(current[id]!);
      }
    },
  );

  Future<({bool changed, bool needsRetry})> runDue(DateTime now) async {
    var changed = false, needsRetry = false;
    final eligible = <String>[];
    final pending = <InstallmentRepricingCandidate>[];
    for (final id in await records.contractIdsForRepricing()) {
      try {
        final contract = await installments.findContract(id);
        if (contract == null) continue;
        final existing = {
          for (final record in contract.repricings)
            (record.stageId, referenceDate(record.change.effectiveDate)),
        };
        pending.addAll(
          _pending(contract, now).where(
            (candidate) => !existing.contains((
              candidate.configuration.stageId,
              candidate.effectiveDate,
            )),
          ),
        );
        eligible.add(id);
      } on Exception catch (error, stack) {
        needsRetry = true;
        _logFailure(error, stack);
      }
    }
    final resolved = await _resolvePending(pending);
    for (final id in eligible) {
      try {
        if (!await prepare(id, now, resolvedRates: resolved)) needsRetry = true;
        if (await _applyPending(id)) changed = true;
      } on Exception catch (error, stack) {
        needsRetry = true;
        _logFailure(error, stack);
      }
    }
    return (changed: changed, needsRetry: needsRetry);
  }

  List<InstallmentRepricingCandidate> _pending(
    InstallmentContract contract,
    DateTime now,
  ) => const InstallmentRepricingPlanner().due(
    configurations: contract.repricingConfigurations,
    borrowingDate: contract.borrowingDate,
    terms: contract.stageTerms,
    now: now,
  );

  Future<Map<(InterestRateType, DateTime), ReferenceRate?>> _resolvePending(
    List<InstallmentRepricingCandidate> pending,
  ) async {
    if (pending.isEmpty) return {};
    final types = {
      for (final candidate in pending)
        candidate.configuration.rule.referenceRateType,
    };
    final dates = {
      for (final candidate in pending) _rateThrough(candidate.resetDate),
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

  RateChange _change(
    InstallmentRepricingCandidate candidate,
    ReferenceRate rate,
  ) {
    final rule = candidate.configuration.rule;
    final change = RateChange(
      resetDate: candidate.resetDate,
      effectiveDate: candidate.effectiveDate,
      referenceRate: rate,
      spreadBp: rule.spreadBp,
    );
    change.validate();
    if (rate.type != rule.referenceRateType ||
        !referenceDate(rate.date).isBefore(candidate.resetDate)) {
      _invalid('参考利率不适用于本次重定价');
    }
    return change;
  }

  void _validateDates(
    InstallmentContract contract,
    String stageId,
    DateTime resetDate,
    DateTime effectiveDate,
  ) {
    final range = contract.stageTerms.repaymentRange(
      stageId,
      contract.borrowingDate,
    );
    if (effectiveDate.isBefore(resetDate) ||
        effectiveDate.isBefore(referenceDate(contract.borrowingDate)) ||
        !effectiveDate.isBefore(range.end)) {
      _invalid('重定价生效日不得早于重定价日或借款日，且不得晚于所属阶段末期还款日');
    }
  }

  Future<InstallmentContract> _requireContract(String id) async =>
      await installments.findContract(id) ??
      (throw BusinessException(CreditErrorCode.contractNotFound));

  DateTime _rateThrough(DateTime reset) =>
      referenceDate(reset).subtract(const Duration(days: 1));
  Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
  void _logFailure(Exception error, StackTrace stack) =>
      Logger('application.credit.repricing').log(
        error is BusinessException ? Level.WARNING : Level.SEVERE,
        'Loan repricing failed; it will retry after its cooldown.',
        error,
        stack,
      );
}
