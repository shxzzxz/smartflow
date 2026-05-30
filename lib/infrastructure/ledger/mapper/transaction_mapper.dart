import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/transaction.dart';
import '../../../domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/data/app_database.dart';

Transaction mapTransaction(TransactionRow row) {
  return Transaction(
    id: row.id,
    rootTransactionId: row.rootTransactionId ?? row.id,
    businessPurpose: row.businessPurpose,
    occurredAt: row.occurredAt,
    primaryAmount: Money(minorUnits: row.primaryAmountMinor),
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
  );
}
