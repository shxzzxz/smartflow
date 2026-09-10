import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import '../../valobj/installment_contract_terms.dart';

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
    String? disbursementAccountId,
    String? disbursementTransactionId,
  }) {
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
        stageTerms: terms.stageTerms,
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
    String? productId,
    String? productName,
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
      productId: productId,
      productName: productName,
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
    final plan = _planEngine.generate(
      stageTerms.planTerms(terms.principal, terms.borrowingDate),
    );
    final entries = plan.entries;
    final stageIdsByPeriod = {
      for (final entry in entries)
        entry.periodNo: stageTerms.stages[entry.stageIndex].id,
    };
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
