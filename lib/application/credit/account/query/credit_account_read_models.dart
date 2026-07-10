import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

export 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart'
    show CreditDebtBuckets;

class CreditAccountOverviewReadModel {
  const CreditAccountOverviewReadModel({
    required this.creditAccount,
    required this.liabilityBalance,
    required this.buckets,
    required this.unattributedRepayments,
    this.availableCredit,
  });

  final CreditLiabilityAccount creditAccount;
  final Money liabilityBalance;
  final Money? availableCredit;
  final CreditDebtBuckets buckets;
  final List<CreditRepaymentRecordReadModel> unattributedRepayments;
}

enum CreditRepaymentTimeSource { transaction, recordCreatedAt }

class CreditRepaymentRecordReadModel {
  const CreditRepaymentRecordReadModel({
    required this.id,
    required this.repaymentType,
    required this.allocated,
    required this.displayTime,
    required this.timeSource,
    this.rootTransactionId,
    this.paidFromAccountId,
  });

  final String id;
  final RepaymentType repaymentType;
  final RepaymentAmountBreakdown allocated;
  final DateTime displayTime;
  final CreditRepaymentTimeSource timeSource;
  final String? rootTransactionId;
  final String? paidFromAccountId;
}

enum ContractEffectiveRateUnavailableReason { principalMismatch, notConverged }

class ContractEffectiveRateReadModel {
  const ContractEffectiveRateReadModel._({
    required this.contractId,
    required this.isCalculable,
    this.unavailableReason,
    this.monthlyIrr,
    this.nominalApr,
    this.effectiveApr,
    this.totalRepayment,
  });

  factory ContractEffectiveRateReadModel.available({
    required String contractId,
    required double monthlyIrr,
    required double nominalApr,
    required double effectiveApr,
    required Money totalRepayment,
  }) {
    return ContractEffectiveRateReadModel._(
      contractId: contractId,
      isCalculable: true,
      monthlyIrr: monthlyIrr,
      nominalApr: nominalApr,
      effectiveApr: effectiveApr,
      totalRepayment: totalRepayment,
    );
  }

  factory ContractEffectiveRateReadModel.unavailable({
    required String contractId,
    required ContractEffectiveRateUnavailableReason reason,
  }) {
    return ContractEffectiveRateReadModel._(
      contractId: contractId,
      isCalculable: false,
      unavailableReason: reason,
    );
  }

  final String contractId;
  final bool isCalculable;
  final ContractEffectiveRateUnavailableReason? unavailableReason;
  final double? monthlyIrr;
  final double? nominalApr;
  final double? effectiveApr;
  final Money? totalRepayment;
}

enum CreditDueCalendarItemSource { billItem, schedule }

class CreditDueCalendarItemReadModel {
  const CreditDueCalendarItemReadModel._({
    required this.source,
    required this.accountId,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.fee,
    this.billId,
    this.billItemId,
    this.itemType,
    this.contractId,
    this.scheduleId,
  });

  factory CreditDueCalendarItemReadModel.billItem({
    required String accountId,
    required String billId,
    required String billItemId,
    required DateTime dueDate,
    required BillItemType itemType,
    required Money principal,
    required Money interest,
    required Money fee,
    String? contractId,
    String? scheduleId,
  }) {
    return CreditDueCalendarItemReadModel._(
      source: CreditDueCalendarItemSource.billItem,
      accountId: accountId,
      billId: billId,
      billItemId: billItemId,
      itemType: itemType,
      dueDate: dueDate,
      principal: principal,
      interest: interest,
      fee: fee,
      contractId: contractId,
      scheduleId: scheduleId,
    );
  }

  factory CreditDueCalendarItemReadModel.schedule({
    required String accountId,
    required String contractId,
    required String scheduleId,
    required DateTime dueDate,
    required Money principal,
    required Money interest,
    required Money fee,
  }) {
    return CreditDueCalendarItemReadModel._(
      source: CreditDueCalendarItemSource.schedule,
      accountId: accountId,
      dueDate: dueDate,
      principal: principal,
      interest: interest,
      fee: fee,
      contractId: contractId,
      scheduleId: scheduleId,
    );
  }

  final CreditDueCalendarItemSource source;
  final String accountId;
  final String? billId;
  final String? billItemId;
  final BillItemType? itemType;
  final String? contractId;
  final String? scheduleId;
  final DateTime dueDate;
  final Money principal;
  final Money interest;
  final Money fee;
}

class MonthlyBillSummaryReadModel {
  const MonthlyBillSummaryReadModel({
    required this.accountId,
    required this.billId,
    required this.period,
    required this.status,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.pendingPrincipal,
    required this.itemCount,
    this.dueDate,
  });

  final String accountId;
  final String billId;
  final BillPeriod period;
  final DateTime? dueDate;
  final BillStatus status;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final Money pendingPrincipal;
  final int itemCount;
}
