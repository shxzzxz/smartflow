import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/credit/entity/installment_contract.dart';
import '../../../../domain/credit/entity/installment_schedule.dart';
import '../../../../domain/credit/port/bill_repository.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/service/installment/installment_lifecycle_service.dart';
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/bill_enums.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/equal_installment_amount.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../shared/transaction_runner.dart';

class InstallmentPlanPreview {
  const InstallmentPlanPreview({
    required this.change,
    required this.token,
    required this.hasFrozenPeriods,
    required this.hasIssuedBills,
  });
  final InstallmentPlanChangeSet change;
  final String token;
  final bool hasFrozenPeriods, hasIssuedBills;
  bool get requiresReview => change.affectsManualAdjustments;
}

/// 统一计划变更的事实加载、预览校验和保存。嵌套调用参与外层用例事务。
class InstallmentPlanService {
  InstallmentPlanService({
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required BillRepository bills,
    required TransactionRunner runner,
    required IdGenerator idGenerator,
    InstallmentPlanEngine engine = const InstallmentPlanEngine(),
  }) : _installments = installments,
       _repayments = repayments,
       _bills = bills,
       _runner = runner,
       _ids = idGenerator,
       _engine = engine;

  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final BillRepository _bills;
  final TransactionRunner _runner;
  final IdGenerator _ids;
  final InstallmentPlanEngine _engine;

  Future<InstallmentPlanPreview> previewChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  ) => _runner.run(() async => (await _prepare(contractId, request)).preview);

  Future<void> confirmChange(
    String contractId,
    InstallmentPlanChangeRequest request, {
    required String token,
    bool automatic = false,
  }) => _runner.run(() async {
    final prepared = await _prepare(contractId, request);
    if (prepared.preview.token != token ||
        (automatic && prepared.preview.requiresReview)) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '合同、计划或还款状态已变化，请重新预览',
      );
    }
    await _save(prepared);
  });

  Future<void> applyAutomaticChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  ) => _runner.run(() async {
    if (request is RecalculateFromTerms) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '按合同配置重算须先预览再确认',
      );
    }
    final prepared = await _prepare(contractId, request);
    if (request is ApplyInstallmentRepricing &&
        prepared.preview.requiresReview) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '本次重定价需要预览确认',
      );
    }
    await _save(prepared);
  });

  Future<_PreparedPlan> _prepare(
    String id,
    InstallmentPlanChangeRequest request,
  ) async {
    final contract = await _installments.findContract(id);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    contract.ensureEditable();
    if (request is ApplyInstallmentRepricing &&
        request.record.contractId != id) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
    final schedules = await _installments.listSchedules(id);
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      id,
    );
    final context = InstallmentPlanContext.fromContract(
      contract: contract,
      schedules: schedules,
      prepaymentPrincipal: Money(
        minorUnits: const InstallmentLifecycleService()
            .prepaymentPrincipalMinor(repayments),
      ),
    );
    final change = _engine.recalculate(context, request);
    final affected =
        change.recalculatedRows.map((r) => r.id).whereType<String>().toSet()
          ..addAll(change.removed.map((r) => r.id).whereType<String>());
    final issued = <List<Object?>>[];
    if (request is ApplyInstallmentRepricing) {
      final bills = await _bills.listBillsByAccount(
        contract.liabilityAccountId,
      );
      for (final bill in bills) {
        if (bill.status == BillStatus.open) continue;
        for (final item in bill.items) {
          if (affected.contains(item.scheduleId)) {
            issued.add([bill.id, bill.status.name, item.id, item.scheduleId]);
          }
        }
      }
      issued.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    }
    final frozen =
        request is ApplyInstallmentRepricing &&
        context.rows.any(
          (r) =>
              !r.isPending &&
              _day(
                    r.date,
                  ).compareTo(_day(request.record.change.effectiveDate)) >
                  0,
        );
    final token = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              contract.id,
              contract.status.name,
              contract.liabilityAccountId,
              context.principal.minorUnits,
              _day(context.borrowingDate),
              _termsFacts(context.terms),
              context.prepaymentPrincipal.minorUnits,
              for (final row in [
                ...context.rows,
              ]..sort((a, b) => a.periodNo.compareTo(b.periodNo)))
                [
                  row.id,
                  row.stageId,
                  row.periodNo,
                  _day(row.date),
                  row.principal.minorUnits,
                  row.interest.minorUnits,
                  row.fee.minorUnits,
                  row.status.name,
                  row.manuallyAdjusted,
                ],
              _requestFacts(request),
              issued,
            ]),
          ),
        )
        .toString();
    return _PreparedPlan(
      contract,
      schedules,
      InstallmentPlanPreview(
        change: change,
        token: token,
        hasFrozenPeriods: frozen,
        hasIssuedBills: issued.isNotEmpty,
      ),
    );
  }

  Future<void> _save(_PreparedPlan prepared) async {
    final rows = prepared.contract.applyPlanChange(
      prepared.preview.change,
      schedules: prepared.schedules,
      newId: _ids.newId,
      createdAt: DateTime.now(),
    );
    await _installments.saveAggregate(prepared.contract, rows);
  }
}

class _PreparedPlan {
  const _PreparedPlan(this.contract, this.schedules, this.preview);
  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
  final InstallmentPlanPreview preview;
}

String _day(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day).toIso8601String();

Object _requestFacts(InstallmentPlanChangeRequest request) => switch (request) {
  RecalculateFromTerms(:final terms) => ['terms', _termsFacts(terms)],
  RecalculateAfterPrepayment(:final repaymentDate) => [
    'prepayment',
    _day(repaymentDate),
  ],
  ApplyInstallmentRepricing(:final record) => [
    'repricing',
    record.id,
    record.contractId,
    record.stageId,
    record.applied,
    _rateFacts(record.change),
  ],
};

Object _rateFacts(RateChange value) => [
  _day(value.resetDate),
  _day(value.effectiveDate),
  value.spreadBp,
  value.referenceRate.type.name,
  _day(value.referenceRate.date),
  value.referenceRate.ratePpm,
];

Object _termsFacts(InstallmentContractTerms terms) => [
  terms.dayCount.daysPerMonth,
  terms.dayCount.daysPerYear,
  terms.rounding.name,
  terms.tailDifference.name,
  for (final config in terms.stages)
    [
      config.id,
      switch (config.terms) {
        DefermentStage(:final until) => ['deferment', _day(until)],
        final AmortizingStage stage => [
          'amortizing',
          stage.method.name,
          [for (final date in stage.dates.getDates()) _day(date)],
          stage.dates.intervalMonths,
          stage.accrualStartDate == null ? null : _day(stage.accrualStartDate!),
          stage.rate?.period.name,
          stage.rate?.ppm,
          stage.accrual.name,
          stage.endPrincipal?.minorUnits,
          stage.fee.minorUnits,
          switch (stage.installmentAmount) {
            NominalRateInstallmentAmount() => ['nominal'],
            ActualRateInstallmentAmount() => ['actual'],
            FixedInstallmentAmount(:final amount) => [
              'fixed',
              amount.minorUnits,
            ],
          },
          if (stage.floatingRate case final rule?)
            [
              rule.referenceRateType.name,
              rule.spreadBp,
              _day(rule.firstResetDate),
              _day(rule.firstEffectiveDate),
              rule.cycleMonths,
              rule.paymentTiming.name,
            ]
          else
            null,
          [for (final rate in stage.rateChanges) _rateFacts(rate)],
        ],
      },
    ],
];
