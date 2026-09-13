import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/credit/entity/installment_contract.dart';
import '../../../../domain/credit/entity/installment_schedule.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/entity/bill.dart';
import '../../../../domain/credit/port/bill_repository.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/equal_installment_amount.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../shared/transaction_runner.dart';
import 'installment_status_repair_app_service.dart';

class InstallmentPlanPreview {
  const InstallmentPlanPreview({required this.change, required this.token});
  final InstallmentPlanChangeSet change;
  final String token;
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
    RecalculateFromTerms request,
  ) => _runner.run(() async {
    final prepared = await _prepare(contractId, request);
    return InstallmentPlanPreview(
      change: prepared.change,
      token: _previewToken(prepared, request),
    );
  });

  Future<void> confirmChange(
    String contractId,
    RecalculateFromTerms request, {
    required String token,
  }) => _runner.run(() async {
    final prepared = await _prepare(contractId, request);
    if (_previewToken(prepared, request) != token) {
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
    final schedules = await _installments.listSchedules(id);
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      id,
    );
    final terms = request is RecalculateFromTerms
        ? request.terms
        : contract.stageTerms;
    terms.validate();
    final operations = InstallmentPlanOperations(
      principalReductions: [
        for (final repayment in repayments)
          if (repayment.repaymentType == RepaymentType.prepayment &&
              repayment.totalAllocated().principal.minorUnits > 0)
            PrincipalReduction(
              date: repayment.repaymentDate,
              principal: repayment.totalAllocated().principal,
            ),
      ],
      rateChangesByStage: {
        for (var index = 0; index < terms.stages.length; index++)
          if (terms.stages[index].terms is AmortizingStage)
            index: [
              for (final record in contract.repricings)
                if (record.stageId == terms.stages[index].id) record.change,
            ],
      },
      interestAdjustments: [
        for (final record in contract.interestAdjustments) record.adjustment,
      ],
    );
    final context = InstallmentPlanContext.fromContract(
      contract: contract,
      schedules: schedules,
      operations: operations,
    );
    if (terms.isCustom && request is! RecalculateFromTerms) {
      return _PreparedPlan(
        contract,
        schedules,
        InstallmentPlanChangeSet(
          context: context,
          terms: terms,
          rows: context.rows,
        ),
      );
    }
    final plan = _engine.generate(
      terms.planTerms(contract.principal, contract.borrowingDate),
      operations: operations,
    );
    final previous = {for (final row in context.rows) row.periodNo: row};
    final change = InstallmentPlanChangeSet(
      context: context,
      terms: terms,
      rows: [
        for (final entry in plan.entries)
          if (terms.isCustom && previous[entry.periodNo] != null)
            InstallmentPlanRow(
              id: previous[entry.periodNo]!.id,
              stageId: terms.stages[entry.stageIndex].id,
              periodNo: entry.periodNo,
              date: previous[entry.periodNo]!.date,
              principal: previous[entry.periodNo]!.principal,
              interest: previous[entry.periodNo]!.interest,
              fee: previous[entry.periodNo]!.fee,
              status: previous[entry.periodNo]!.status,
              manuallyAdjusted: previous[entry.periodNo]!.manuallyAdjusted,
            )
          else
            InstallmentPlanRow(
              id: previous[entry.periodNo]?.id,
              stageId: terms.stages[entry.stageIndex].id,
              periodNo: entry.periodNo,
              date: entry.expectedRepaymentDate,
              principal: entry.expectedPrincipal,
              interest: entry.expectedInterest,
              fee: entry.expectedFee,
              status:
                  previous[entry.periodNo]?.status ??
                  InstallmentScheduleStatus.pending,
            ),
      ],
    );
    return _PreparedPlan(contract, schedules, change);
  }

  String _previewToken(_PreparedPlan prepared, RecalculateFromTerms request) {
    final contract = prepared.contract;
    final context = prepared.change.context;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              contract.id,
              contract.status.name,
              contract.liabilityAccountId,
              context.principal.minorUnits,
              _day(context.borrowingDate),
              _termsFacts(context.terms),
              _operationFacts(context.operations),
              for (final record in [
                ...contract.repricings,
              ]..sort((a, b) => a.id.compareTo(b.id)))
                [record.id, record.stageId, _rateFacts(record.change)],
              for (final config in [
                ...contract.repricingConfigurations,
              ]..sort((a, b) => a.id.compareTo(b.id)))
                [
                  config.id,
                  config.stageId,
                  _day(config.effectiveFrom),
                  config.rule.referenceRateType.name,
                  config.rule.spreadBp,
                  config.rule.cycleMonths,
                  _day(config.rule.firstResetDate),
                  _day(config.rule.firstEffectiveDate),
                  config.lastGeneratedDate == null
                      ? null
                      : _day(config.lastGeneratedDate!),
                ],
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
              _termsFacts(request.terms),
            ]),
          ),
        )
        .toString();
  }

  Future<void> _save(_PreparedPlan prepared) async {
    final rows = prepared.contract.applyPlanChange(
      prepared.change,
      schedules: prepared.schedules,
      newId: _ids.newId,
      createdAt: DateTime.now(),
    );
    await _installments.saveAggregate(prepared.contract, rows);
    await _detachRemovedScheduleReferences(prepared, rows);
    await InstallmentStatusRepairAppService(
      installments: _installments,
      bills: _bills,
      repayments: _repayments,
      transactionRunner: _runner,
    ).validateAndRepair(prepared.contract.id);
  }

  Future<void> _detachRemovedScheduleReferences(
    _PreparedPlan prepared,
    List<InstallmentSchedule> rows,
  ) async {
    final retained = rows.map((row) => row.id).toSet();
    final removed = prepared.schedules
        .where((row) => !retained.contains(row.id))
        .map((row) => row.id)
        .toSet();
    if (removed.isEmpty) return;
    for (final bill in await _bills.listBillsByAccount(
      prepared.contract.liabilityAccountId,
    )) {
      if (!bill.items.any((item) => removed.contains(item.scheduleId))) {
        continue;
      }
      await _bills.replaceBillItems(bill.id, [
        for (final item in bill.items)
          if (!removed.contains(item.scheduleId))
            item
          else
            BillItem(
              id: item.id,
              billId: item.billId,
              itemType: item.itemType,
              repaymentDate: item.repaymentDate,
              expectedPrincipal: item.expectedPrincipal,
              expectedInterest: item.expectedInterest,
              expectedFee: item.expectedFee,
              status: item.status,
              billingState: item.billingState,
              contractId: item.contractId,
              createdAt: item.createdAt,
            ),
      ]);
    }
  }
}

class _PreparedPlan {
  const _PreparedPlan(this.contract, this.schedules, this.change);
  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
  final InstallmentPlanChangeSet change;
}

String _day(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day).toIso8601String();

Object _operationFacts(InstallmentPlanOperations operations) => [
  [
    for (final value in [
      ...operations.principalReductions,
    ]..sort((a, b) => a.date.compareTo(b.date)))
      [_day(value.date), value.principal.minorUnits],
  ],
  [
    for (final entry
        in operations.rateChangesByStage.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
      [
        entry.key,
        for (final value in [
          ...entry.value,
        ]..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate)))
          _rateFacts(value),
      ],
  ],
  [
    for (final value in [
      ...operations.interestAdjustments,
    ]..sort((a, b) => a.start.compareTo(b.start)))
      [_day(value.start), _day(value.end), value.ratioPpm],
  ],
];

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
          stage.repricingPaymentTiming.name,
        ],
      },
    ],
];
