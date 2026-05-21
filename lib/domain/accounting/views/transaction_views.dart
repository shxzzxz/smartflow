import '../../../core/money/money.dart';
import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';

class CashflowSummary {
  const CashflowSummary({required this.income, required this.expense});

  final Money income;
  final Money expense;

  Money get net => income - expense;
}

class TransactionListItem {
  const TransactionListItem({
    required this.id,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.accountNames,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    this.accountBalanceDelta,
    this.categoryName,
    this.categoryIconKey,
    this.flowOutAccountId,
    this.flowInAccountId,
    this.flowOutAccountName,
    this.flowInAccountName,
    this.counterpartyName,
    this.note,
    this.refundedTotal,
    this.refundChildCount = 0,
    this.reimbursementReceivedTotal,
    this.reimbursementChildCount = 0,
    this.reimbursementGapIncome,
    this.reimbursementGapExpense,
    this.repaymentInterest,
    this.repaymentFee,
    this.repaymentDiscount,
  });

  final int id;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final Money? accountBalanceDelta;
  final String accountNames;
  final String? categoryName;
  final String? categoryIconKey;
  final int? flowOutAccountId;
  final int? flowInAccountId;
  final String? flowOutAccountName;
  final String? flowInAccountName;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final Money? refundedTotal;
  final int refundChildCount;
  final Money? reimbursementReceivedTotal;
  final int reimbursementChildCount;
  final Money? reimbursementGapIncome;
  final Money? reimbursementGapExpense;
  final Money? repaymentInterest;
  final Money? repaymentFee;
  final Money? repaymentDiscount;
}

class TransactionDetailView {
  const TransactionDetailView({
    required this.transaction,
    required this.details,
    required this.entries,
    this.children = const [],
    this.history = const [],
    this.categoryName,
    this.categoryIconKey,
    this.refundedTotal,
    this.reimbursementSummary,
  });

  final Transaction transaction;
  final List<TransactionDetailLineView> details;
  final List<EntryLineView> entries;
  final List<TransactionListItem> children;
  final List<TransactionListItem> history;
  final String? categoryName;
  final String? categoryIconKey;
  final Money? refundedTotal;
  final ReimbursementSummary? reimbursementSummary;
}

class TransactionDetailLineView {
  const TransactionDetailLineView({
    required this.lineNo,
    required this.type,
    required this.amount,
  });

  final int lineNo;
  final TransactionDetailType type;
  final Money amount;
}

class EntryLineView {
  const EntryLineView({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.direction,
    required this.amount,
    this.accountIconKey,
  });

  final int accountId;
  final String accountName;
  final AccountType accountType;
  final EntryDirection direction;
  final Money amount;
  final String? accountIconKey;
}

class ReimbursementSummary {
  const ReimbursementSummary({
    required this.advanceAmount,
    required this.receivedAmount,
    required this.outstanding,
    required this.isClosed,
  });

  final Money advanceAmount;
  final Money receivedAmount;
  final Money outstanding;
  final bool isClosed;
}
