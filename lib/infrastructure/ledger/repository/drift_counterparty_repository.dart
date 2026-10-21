import 'package:drift/drift.dart';

import '../../../application/ledger/counterparty/query/counterparty_read_models.dart';
import '../../../application/ledger/counterparty/query/port/counterparty_repository.dart';
import '../../database/app_database.dart';

class DriftCounterpartyRepository implements CounterpartyRepository {
  const DriftCounterpartyRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CounterpartyView>> watchCounterparties() {
    final usageCount = _usageCountExpression();
    return _counterpartySelect(
      usageCount,
    ).watch().map((rows) => _mapCounterpartyViews(rows, usageCount));
  }

  @override
  Future<List<CounterpartyView>> listCounterparties() async {
    final usageCount = _usageCountExpression();
    return _mapCounterpartyViews(
      await _counterpartySelect(usageCount).get(),
      usageCount,
    );
  }

  @override
  Future<Map<String, CounterpartyView>> findByIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.counterparties,
    )..where((table) => table.id.isIn(ids))).get();
    return {
      for (final row in rows)
        row.id: CounterpartyView(id: row.id, name: row.name),
    };
  }

  @override
  Future<void> insertCounterparty({required String id, required String name}) {
    return _db
        .into(_db.counterparties)
        .insert(CounterpartiesCompanion.insert(id: id, name: name));
  }

  @override
  Future<void> renameCounterparty({required String id, required String name}) {
    return (_db.update(
      _db.counterparties,
    )..where((table) => table.id.equals(id))).write(
      CounterpartiesCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> reassignTransactionReferences({
    required Set<String> sourceIds,
    required String targetId,
  }) {
    if (sourceIds.isEmpty) return Future.value();
    return (_db.update(
      _db.transactions,
    )..where((table) => table.counterpartyId.isIn(sourceIds))).write(
      TransactionsCompanion(
        counterpartyId: Value(targetId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> clearTransactionReferences(String counterpartyId) {
    return (_db.update(
      _db.transactions,
    )..where((table) => table.counterpartyId.equals(counterpartyId))).write(
      TransactionsCompanion(
        counterpartyId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteCounterparty(String id) {
    return (_db.delete(
      _db.counterparties,
    )..where((table) => table.id.equals(id))).go();
  }

  Expression<int> _usageCountExpression() {
    return subqueryExpression<int>(
      _db.selectOnly(_db.transactions)
        ..addColumns([countAll()])
        ..where(
          _db.transactions.counterpartyId.equalsExp(_db.counterparties.id),
        ),
    );
  }

  JoinedSelectStatement<$CounterpartiesTable, CounterpartyRow>
  _counterpartySelect(Expression<int> usageCount) {
    return _db.selectOnly(_db.counterparties)
      ..addColumns([_db.counterparties.id, _db.counterparties.name, usageCount])
      ..orderBy([OrderingTerm.asc(_db.counterparties.name)]);
  }

  List<CounterpartyView> _mapCounterpartyViews(
    List<TypedResult> rows,
    Expression<int> usageCount,
  ) {
    return [
      for (final row in rows)
        CounterpartyView(
          id: row.read(_db.counterparties.id)!,
          name: row.read(_db.counterparties.name)!,
          usageCount: row.read(usageCount) ?? 0,
        ),
    ];
  }
}
