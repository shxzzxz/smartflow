import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/transaction.dart';
import '../../../domain/accounting/entities/transaction_ownership.dart';
import '../../app_database.dart';

Transaction mapTransaction(TransactionRow row) {
  return Transaction(
    id: row.id,
    rootTransactionId: row.rootTransactionId ?? row.id,
    businessPurpose: row.businessPurpose,
    occurredAt: row.occurredAt,
    currencyCode: row.currencyCode,
    primaryAmount: Money(
      minorUnits: row.primaryAmountMinor,
      currency: row.currencyCode,
    ),
    counterpartyName: row.counterpartyName,
    note: row.note,
    parentTransactionId: row.parentTransactionId,
    reimbursementExpenseAccountId: row.reimbursementExpenseAccountId,
    mutationKind: row.mutationKind,
    mutationPreviousTransactionId: row.mutationPreviousTransactionId,
    mutationReason: row.mutationReason,
    businessState: row.businessState,
    isExcludedFromStats: row.isExcludedFromStats,
    isExcludedFromBudget: row.isExcludedFromBudget,
    sourceKind: row.sourceKind,
    ownership:
        row.ownerType == null
            ? null
            : TransactionOwnership(
              ownerType: row.ownerType!,
              ownerId: row.ownerId,
              ownerRole: row.ownerRole,
            ),
    createdAt: row.createdAt,
  );
}
