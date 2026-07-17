import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_detail_record.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

class CashflowSummary {
  const CashflowSummary({required this.income, required this.expense});

  final Money income;
  final Money expense;

  Money get net => income - expense;
}

class TransactionListReadModel {
  const TransactionListReadModel({
    required this.id,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.entries,
    required this.details,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.refundedTotal,
    this.refundChildCount = 0,
    this.reimbursementReceivedTotal,
    this.reimbursementChildCount = 0,
    this.reimbursementGapIncome,
    this.reimbursementGapExpense,
  });

  final String id;
  final String? parentTransactionId;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final String? reimbursementExpenseAccountId;
  final List<Entry> entries;
  final List<TransactionDetailRecord> details;
  final Money? refundedTotal;
  final int refundChildCount;
  final Money? reimbursementReceivedTotal;
  final int reimbursementChildCount;
  final Money? reimbursementGapIncome;
  final Money? reimbursementGapExpense;
}

class TransactionDetail {
  const TransactionDetail({
    required this.transaction,
    required this.createdAt,
    required this.details,
    required this.entries,
    this.children = const [],
    this.refundedTotal,
    this.reimbursementSummary,
  });

  final Transaction transaction;
  final DateTime createdAt;
  final List<TransactionDetailRecord> details;
  final List<Entry> entries;
  final List<TransactionListReadModel> children;
  final Money? refundedTotal;
  final ReimbursementSummary? reimbursementSummary;
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
