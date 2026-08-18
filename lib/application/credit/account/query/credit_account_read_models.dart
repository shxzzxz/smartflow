import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';

class CreditDebtBucketsReadModel {
  const CreditDebtBucketsReadModel({
    required this.billDebt,
    required this.futureContractDebt,
    required this.unattributedDebt,
  });

  final Money billDebt;
  final Money futureContractDebt;
  final Money unattributedDebt;
}

class CreditAccountOverviewReadModel {
  const CreditAccountOverviewReadModel({
    required this.creditAccount,
    required this.liabilityBalance,
    required this.buckets,
    this.availableCredit,
  });

  final CreditLiabilityAccountReadModel creditAccount;
  final Money liabilityBalance;
  final Money? availableCredit;
  final CreditDebtBucketsReadModel buckets;
}

class CreditDueCalendarItemReadModel {
  const CreditDueCalendarItemReadModel._({
    required this.accountId,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.discount,
    required this.pendingTotal,
    required this.billId,
    required this.billItemId,
    required this.itemType,
    required this.status,
    required this.isOverdue,
    this.contractId,
    this.scheduleId,
  });

  factory CreditDueCalendarItemReadModel.billItem({
    required String accountId,
    required String billId,
    required String billItemId,
    required DateTime dueDate,
    required BillItemType itemType,
    required BillItemStatus status,
    required Money principal,
    required Money interest,
    required Money fee,
    Money discount = const Money(minorUnits: 0),
    required Money pendingTotal,
    required bool isOverdue,
    String? contractId,
    String? scheduleId,
  }) {
    return CreditDueCalendarItemReadModel._(
      accountId: accountId,
      billId: billId,
      billItemId: billItemId,
      itemType: itemType,
      status: status,
      dueDate: dueDate,
      principal: principal,
      interest: interest,
      fee: fee,
      discount: discount,
      pendingTotal: pendingTotal,
      isOverdue: isOverdue,
      contractId: contractId,
      scheduleId: scheduleId,
    );
  }

  final String accountId;
  final String billId;
  final String billItemId;
  final BillItemType itemType;
  final BillItemStatus status;
  final bool isOverdue;
  final String? contractId;
  final String? scheduleId;
  final DateTime dueDate;
  final Money principal;
  final Money interest;
  final Money fee;
  final Money discount;
  final Money pendingTotal;
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
    required this.pendingTotal,
    required this.itemCount,
  });

  final String accountId;
  final String billId;
  final BillPeriod period;
  final BillStatus status;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final Money pendingPrincipal;

  /// 未核销明细的待还总额，含利息、费用并已扣减优惠。
  final Money pendingTotal;
  final int itemCount;
}

class CreditLiabilityAccountReadModel {
  const CreditLiabilityAccountReadModel({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.billingDayToNext,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
  });

  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
}
