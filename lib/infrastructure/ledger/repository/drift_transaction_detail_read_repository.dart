import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/transaction_detail_record.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../application/ledger/query/transaction_detail_read_repository.dart';
import 'package:smartflow/data/app_database.dart';

class DriftTransactionDetailReadRepository
    implements TransactionDetailReadRepository {
  const DriftTransactionDetailReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, List<TransactionDetailRecord>>> findByTransactionIds(
    Set<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const {};

    final rows =
        await (_db.select(_db.transactionDetails)
              ..where((detail) => detail.transactionId.isIn(transactionIds))
              ..orderBy([(detail) => OrderingTerm.asc(detail.lineNo)]))
            .get();

    final result = <String, List<TransactionDetailRecord>>{};
    for (final detailRow in rows) {
      result
          .putIfAbsent(
            detailRow.transactionId,
            () => <TransactionDetailRecord>[],
          )
          .add(
            TransactionDetailRecord(
              id: detailRow.id,
              transactionId: detailRow.transactionId,
              lineNo: detailRow.lineNo,
              type: detailRow.detailType,
              amount: Money(minorUnits: detailRow.amountMinor),
            ),
          );
    }
    return result;
  }

  @override
  Future<Map<String, Map<TransactionDetailType, int>>> sumOwnByType({
    required Set<String> transactionIds,
    required Set<TransactionDetailType> detailTypes,
  }) async {
    if (transactionIds.isEmpty || detailTypes.isEmpty) return const {};

    final sumExpr = _db.transactionDetails.amountMinor.sum();
    final txCol = _db.transactionDetails.transactionId;
    final typeCol = _db.transactionDetails.detailType;

    final select =
        _db.selectOnly(_db.transactionDetails)
          ..addColumns([txCol, typeCol, sumExpr])
          ..where(_db.transactionDetails.transactionId.isIn(transactionIds))
          ..where(_db.transactionDetails.detailType.isInValues(detailTypes))
          ..groupBy([txCol, typeCol]);

    final rows = await select.get();
    final result = <String, Map<TransactionDetailType, int>>{};
    for (final row in rows) {
      final txId = row.read(txCol);
      final typeName = row.read(typeCol);
      final sum = row.read(sumExpr) ?? 0;
      if (txId == null || typeName == null) continue;
      final type = TransactionDetailType.values.byName(typeName);
      result.putIfAbsent(txId, () => <TransactionDetailType, int>{})[type] =
          sum;
    }
    return result;
  }
}
