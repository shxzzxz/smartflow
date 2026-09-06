import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

import '../../valobj/installment_contract_terms.dart';
import '../../valobj/installment_plan_terms.dart';

class InstallmentOriginationTerms {
  const InstallmentOriginationTerms({
    required this.principal,
    required this.borrowingDate,
    this.note,
    required this.stageTerms,
    this.productId,
    this.productName,
    this.customRules = false,
  });

  final Money principal;
  final DateTime borrowingDate;
  final String? note;
  final InstallmentContractTerms stageTerms;
  final String? productId;
  final String? productName;
  final bool customRules;
}

class InstallmentOriginationResult {
  const InstallmentOriginationResult({
    required this.contract,
    required this.schedules,
  });

  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
}

class InstallmentOriginationService {
  const InstallmentOriginationService({
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
  }) : _planEngine = planEngine,
       _lifecycle = lifecycle;

  final InstallmentPlanEngine _planEngine;
  final InstallmentLifecycleService _lifecycle;

  InstallmentOriginationResult originateDisbursement({
    required String contractId,
    required String liabilityAccountId,
    required InstallmentOriginationTerms terms,
    required DateTime createdAt,
    required String Function() newScheduleId,
    CreditLiabilityAccount? creditAccount,
    String? disbursementAccountId,
    String? disbursementTransactionId,
  }) {
    final cycleBounds = _lifecycle.cycleScheduleBoundsForDisbursement(
      creditAccount,
      borrowingDate: terms.borrowingDate,
      totalPeriods: terms.stageTerms.totalPeriods,
    );
    var stages = terms.stageTerms;
    if (cycleBounds != null) {
      if (terms.productId != null ||
          stages.stages.length != 1 ||
          stages.repayments.length != 1) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '信用账户按账期生成单阶段计划',
        );
      }
      final stage = stages.repayments.single;
      stages = InstallmentContractTerms(
        dayCount: stages.dayCount,
        rounding: stages.rounding,
        tailDifference: stages.tailDifference,
        stages: [
          InstallmentContractStage(
            id: stages.stages.single.id,
            terms: AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: cycleBounds.first,
                lastDate: cycleBounds.last,
                count: stages.totalPeriods,
              ),
              method: stage.method,
              rate: stage.rate,
              accrual: stage.accrual,
              endPrincipal: stage.endPrincipal,
              fee: stage.fee,
              installmentAmount: stage.installmentAmount,
            ),
          ),
        ],
      );
    }
    return _originate(
      contractId: contractId,
      liabilityAccountId: liabilityAccountId,
      sourceType: InstallmentSourceType.disbursement,
      disbursementAccountId: disbursementAccountId,
      disbursementTransactionId: disbursementTransactionId,
      terms: InstallmentOriginationTerms(
        principal: terms.principal,
        borrowingDate: terms.borrowingDate,
        note: terms.note,
        productId: terms.productId,
        productName: terms.productName,
        customRules: terms.customRules,
        stageTerms: stages,
      ),
      createdAt: createdAt,
      newScheduleId: newScheduleId,
    );
  }

  InstallmentOriginationResult originateBillConversion({
    required String contractId,
    required Bill bill,
    required String sourceRepaymentId,
    required Money principal,
    required DateTime borrowingDate,
    required InstallmentContractTerms stageTerms,
    required DateTime createdAt,
    required String Function() newScheduleId,
    String? note,
  }) => _originate(
    contractId: contractId,
    liabilityAccountId: bill.accountId,
    sourceType: InstallmentSourceType.billConversion,
    sourceRepaymentId: sourceRepaymentId,
    terms: InstallmentOriginationTerms(
      principal: principal,
      borrowingDate: borrowingDate,
      stageTerms: stageTerms,
      note: note,
      customRules: true,
    ),
    createdAt: createdAt,
    newScheduleId: newScheduleId,
  );

  InstallmentOriginationResult _originate({
    required String contractId,
    required String liabilityAccountId,
    required InstallmentSourceType sourceType,
    required InstallmentOriginationTerms terms,
    required DateTime createdAt,
    required String Function() newScheduleId,
    String? sourceRepaymentId,
    String? disbursementAccountId,
    String? disbursementTransactionId,
  }) {
    if (terms.principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '本金必须大于零',
      );
    }
    final stageTerms = terms.stageTerms;
    stageTerms.validate();
    final plan = _planEngine.plan(
      stageTerms.planTerms(terms.principal, terms.borrowingDate),
    );
    final entries = plan.entries;
    final stageIdsByPeriod = <int, String>{};
    var period = 1;
    for (final stage in stageTerms.stages) {
      if (stage.terms case AmortizingStage(:final dates)) {
        for (var i = 0; i < dates.getDates().length; i++) {
          stageIdsByPeriod[period++] = stage.id;
        }
      }
    }
    final contract = InstallmentContract(
      id: contractId,
      liabilityAccountId: liabilityAccountId,
      sourceType: sourceType,
      sourceRepaymentId: sourceRepaymentId,
      disbursementAccountId: disbursementAccountId,
      disbursementTransactionId: disbursementTransactionId,
      principal: terms.principal,
      borrowingDate: terms.borrowingDate,
      productId: terms.productId,
      productName: terms.productName,
      customRules: terms.customRules,
      status: InstallmentContractStatus.active,
      note: terms.note,
      createdAt: createdAt,
      stageTerms: stageTerms,
    );
    return InstallmentOriginationResult(
      contract: contract,
      schedules: _lifecycle.schedulesFromEntries(
        contractId: contractId,
        entries: entries,
        createdAt: createdAt,
        newId: newScheduleId,
        stageIdsByPeriod: stageIdsByPeriod,
      ),
    );
  }
}
