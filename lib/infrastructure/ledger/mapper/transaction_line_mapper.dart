import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/transaction_line.dart';
import '../../database/app_database.dart';

TransactionLine mapTransactionLine(TransactionLineRow row) {
  return TransactionLine(
    id: row.id,
    transactionId: row.transactionId,
    lineNo: row.lineNo,
    role: row.role,
    accountId: row.accountId,
    amount: Money(minorUnits: row.amountMinor),
  );
}

TransactionLinesCompanion transactionLineCompanion(
  TransactionLine line, {
  required String transactionId,
  required String id,
  required DateTime now,
}) {
  return TransactionLinesCompanion.insert(
    id: id,
    transactionId: transactionId,
    lineNo: line.lineNo,
    role: line.role,
    accountId: Value(line.accountId),
    amountMinor: line.amount.minorUnits,
    createdAt: Value(now),
    updatedAt: Value(now),
  );
}
