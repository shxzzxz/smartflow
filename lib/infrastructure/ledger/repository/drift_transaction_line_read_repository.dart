import 'package:drift/drift.dart';

import '../../../domain/ledger/entity/transaction_line.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../application/ledger/ledger_query_port_api.dart';
import '../../database/app_database.dart';
import '../mapper/transaction_line_mapper.dart';

class DriftTransactionLineReadRepository
    implements TransactionLineReadRepository {
  const DriftTransactionLineReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, List<TransactionLine>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const {};

    final rows =
        await (_db.select(_db.transactionLines)
              ..where((line) => line.transactionId.isIn(transactionIds))
              ..orderBy([(line) => OrderingTerm.asc(line.lineNo)]))
            .get();

    final result = <String, List<TransactionLine>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.transactionId, () => <TransactionLine>[])
          .add(mapTransactionLine(row));
    }
    return result;
  }

  @override
  Future<Map<String, Map<TransactionRole, int>>> sumOwnByRole({
    required Set<String> transactionIds,
    required Set<TransactionRole> roles,
  }) async {
    if (transactionIds.isEmpty || roles.isEmpty) return const {};

    final sumExpr = _db.transactionLines.amountMinor.sum();
    final txCol = _db.transactionLines.transactionId;
    final roleCol = _db.transactionLines.role;

    final select =
        _db.selectOnly(_db.transactionLines)
          ..addColumns([txCol, roleCol, sumExpr])
          ..where(txCol.isIn(transactionIds))
          ..where(roleCol.isInValues(roles))
          ..groupBy([txCol, roleCol]);

    final rows = await select.get();
    final result = <String, Map<TransactionRole, int>>{};
    for (final row in rows) {
      final txId = row.read(txCol);
      final roleName = row.read(roleCol);
      if (txId == null || roleName == null) continue;
      result.putIfAbsent(txId, () => <TransactionRole, int>{})[TransactionRole
          .values
          .byName(roleName)] = row.read(sumExpr) ?? 0;
    }
    return result;
  }
}
