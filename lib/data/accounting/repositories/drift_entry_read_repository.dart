import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/entry.dart';
import '../../../domain/accounting/repositories/entry_read_repository.dart';
import '../../app_database.dart';

class DriftEntryReadRepository implements EntryReadRepository {
  const DriftEntryReadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<int, List<Entry>>> findByTransactionIds(Set<int> transactionIds) async {
    if (transactionIds.isEmpty) return const {};

    // 同时取交易货币用于 Money 构造。entries 表没有 currency_code,join transactions 取。
    final txCurrencyCol = _db.transactions.currencyCode;
    final rows = await (_db.select(_db.entries).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.entries.transactionId),
      ),
    ])
          ..where(_db.entries.transactionId.isIn(transactionIds))
          ..orderBy([OrderingTerm.asc(_db.entries.id)]))
        .get();

    final result = <int, List<Entry>>{};
    for (final row in rows) {
      final entryRow = row.readTable(_db.entries);
      final currency = row.read(txCurrencyCol);
      result.putIfAbsent(entryRow.transactionId, () => <Entry>[]).add(
        Entry(
          id: entryRow.id,
          transactionId: entryRow.transactionId,
          accountId: entryRow.accountId,
          direction: entryRow.direction,
          amount: Money(
            minorUnits: entryRow.amountMinor,
            currency: currency ?? Money.defaultCurrency,
          ),
        ),
      );
    }
    return result;
  }
}
