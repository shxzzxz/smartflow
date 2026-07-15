import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../../repayment/repayment_amount_dto.dart';

class BillSummaryReadModel {
  const BillSummaryReadModel({
    required this.id,
    required this.accountId,
    required this.period,
    required this.status,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.pendingPrincipal,
    required this.itemCount,
    required this.overdueItemCount,
    this.dueDate,
  });

  final String id;
  final String accountId;
  final BillPeriod period;
  final BillStatus status;
  final DateTime? dueDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final Money pendingPrincipal;
  final int itemCount;
  final int overdueItemCount;
}

class BillDetailReadModel {
  const BillDetailReadModel({
    required this.summary,
    required this.items,
    required this.repayments,
  });

  final BillSummaryReadModel summary;
  final List<BillItemReadModel> items;
  final List<BillRepaymentReadModel> repayments;
}

class BillItemReadModel {
  const BillItemReadModel({
    required this.id,
    required this.itemType,
    required this.status,
    required this.repaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.allocated,
    required this.isOverdue,
    this.accountKind,
    this.installmentSourceType,
    this.contractId,
    this.scheduleId,
  });

  final String id;
  final BillItemType itemType;
  final BillItemStatus status;
  final DateTime repaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final RepaymentAmountDto allocated;
  final bool isOverdue;
  final CreditLiabilityAccountKind? accountKind;
  final InstallmentSourceType? installmentSourceType;
  final String? contractId;
  final String? scheduleId;
}

enum BillRepaymentTimeSource { transaction, recordCreatedAt }

class BillRepaymentReadModel {
  const BillRepaymentReadModel({
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
  final RepaymentAmountDto allocated;
  final DateTime displayTime;
  final BillRepaymentTimeSource timeSource;
  final String? rootTransactionId;
  final String? paidFromAccountId;

  Money get cashPaid =>
      allocated.principal +
      allocated.interest +
      allocated.fee -
      allocated.discount;
}
