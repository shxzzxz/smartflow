import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/entry.dart';
import '../../../application/accounting/queries/entry_read_repository.dart';
import 'package:smartflow/data/app_database.dart';

class DriftEntryReadRepository implements EntryReadRepository {
  const DriftEntryReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<int, List<Entry>>> findByTransactionIds(
    Set<int> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return const {};

    final rows =
        await (_db.select(_db.entries)
              ..where((entry) => entry.transactionId.isIn(transactionIds))
              ..orderBy([(entry) => OrderingTerm.asc(entry.id)]))
            .get();

    final result = <int, List<Entry>>{};
    for (final entryRow in rows) {
      result
          .putIfAbsent(entryRow.transactionId, () => <Entry>[])
          .add(
            Entry(
              id: entryRow.id,
              transactionId: entryRow.transactionId,
              accountId: entryRow.accountId,
              direction: entryRow.direction,
              amount: Money(minorUnits: entryRow.amountMinor),
            ),
          );
    }
    return result;
  }
}
