import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../domain/ledger/entity/account_group.dart';
import '../../../domain/ledger/port/account_group_repository.dart';
import '../../../domain/ledger/port/account_repository.dart';
import '../../database/app_database.dart';

class DriftAccountGroupRepository implements AccountGroupRepository {
  DriftAccountGroupRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AccountGroup?> findById(String id) async {
    final row =
        await (_database.select(_database.accountGroups)
          ..where((group) => group.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<List<AccountGroup>> findAll() async {
    final rows = await _orderedQuery().get();
    return rows.map(_map).toList();
  }

  @override
  Stream<List<AccountGroup>> watchAll() {
    return _orderedQuery().watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<void> create(AccountGroup group) {
    final now = DateTime.now();
    return _database
        .into(_database.accountGroups)
        .insert(
          AccountGroupsCompanion.insert(
            id: group.id,
            name: group.name,
            sortOrder: Value(group.sortOrder),
            version: Value(group.version),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> save(AccountGroup group) => _update(group);

  @override
  Future<void> saveAll(Iterable<AccountGroup> groups) {
    return Future.forEach(groups, _update);
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(_database.accountGroups)
      ..where((group) => group.id.equals(id))).go();
  }

  SimpleSelectStatement<$AccountGroupsTable, AccountGroupRow> _orderedQuery() {
    return _database.select(_database.accountGroups)..orderBy([
      (group) => OrderingTerm.asc(group.sortOrder),
      (group) => OrderingTerm.asc(group.name),
    ]);
  }

  AccountGroup _map(AccountGroupRow row) {
    return AccountGroup(
      id: row.id,
      name: row.name,
      sortOrder: row.sortOrder,
      version: row.version,
    );
  }

  Future<void> _update(AccountGroup group) async {
    final updated = await (_database.update(_database.accountGroups)..where(
      (row) => row.id.equals(group.id) & row.version.equals(group.version),
    )).write(
      AccountGroupsCompanion(
        name: Value(group.name),
        sortOrder: Value(group.sortOrder),
        version: Value(group.version + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (updated != 1) {
      throw BusinessException(AccountRepositoryErrorCode.concurrentUpdate);
    }
    group.version += 1;
  }
}
