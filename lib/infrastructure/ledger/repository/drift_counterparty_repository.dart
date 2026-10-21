import 'package:drift/drift.dart';

import '../../../application/ledger/counterparty/query/counterparty_read_models.dart';
import '../../../application/ledger/counterparty/query/port/counterparty_repository.dart';
import '../../database/app_database.dart';

class DriftCounterpartyRepository implements CounterpartyRepository {
  const DriftCounterpartyRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CounterpartyView>> watchCounterparties() {
    return (_db.select(
      _db.counterparties,
    )..orderBy([(table) => OrderingTerm.asc(table.name)])).watch().map(
      (rows) => [
        for (final row in rows) CounterpartyView(id: row.id, name: row.name),
      ],
    );
  }

  @override
  Future<List<CounterpartyView>> listCounterparties() async {
    final rows = await (_db.select(
      _db.counterparties,
    )..orderBy([(table) => OrderingTerm.asc(table.name)])).get();
    return [
      for (final row in rows) CounterpartyView(id: row.id, name: row.name),
    ];
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
}
