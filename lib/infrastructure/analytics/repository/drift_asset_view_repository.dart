import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../domain/analytics/entity/asset_view.dart';
import '../../../domain/analytics/port/asset_view_repository.dart';
import '../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../../application/analytics/asset_view/query/port/asset_view_query_source.dart';
import '../../database/app_database.dart';

class DriftAssetViewRepository
    implements AssetViewRepository, AssetViewQuerySource {
  const DriftAssetViewRepository(this._database);
  final AppDatabase _database;

  @override
  Future<AssetView?> findView(String id) async {
    final row = await (_database.select(
      _database.assetViews,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<List<AssetView>> findViews() async =>
      (await _ordered().get()).map(_map).toList();
  @override
  Stream<List<AssetView>> watchViews() =>
      _ordered().watch().map((rows) => rows.map(_map).toList());

  SimpleSelectStatement<$AssetViewsTable, AssetViewRow> _ordered() =>
      _database.select(_database.assetViews)..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.id),
      ]);

  @override
  Future<void> create(AssetView view) async {
    await _database
        .into(_database.assetViews)
        .insert(
          AssetViewsCompanion.insert(
            id: view.id,
            name: view.name,
            accountIdsJson: Value(jsonEncode(view.accountIds)),
            groupsJson: Value(_groupsJson(view)),
            accountGroupIdsJson: Value(jsonEncode(view.accountGroupIds)),
            sortOrder: Value(view.sortOrder),
          ),
        );
  }

  @override
  Future<void> save(AssetView view) async {
    final updated =
        await (_database.update(_database.assetViews)..where(
              (row) =>
                  row.id.equals(view.id) & row.version.equals(view.version),
            ))
            .write(
              AssetViewsCompanion(
                name: Value(view.name),
                accountIdsJson: Value(jsonEncode(view.accountIds)),
                groupsJson: Value(_groupsJson(view)),
                accountGroupIdsJson: Value(jsonEncode(view.accountGroupIds)),
                sortOrder: Value(view.sortOrder),
                version: Value(view.version + 1),
                updatedAt: Value(DateTime.now()),
              ),
            );
    if (updated != 1) {
      throw BusinessException(AnalyticsErrorCode.concurrentUpdate);
    }
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.assetViews,
    )..where((row) => row.id.equals(id))).go();
  }

  String _groupsJson(AssetView view) => jsonEncode([
    for (final group in view.groups) {'id': group.id, 'name': group.name},
  ]);

  AssetView _map(AssetViewRow row) {
    try {
      final accounts = _strings(jsonDecode(row.accountIdsJson));
      final groups = jsonDecode(row.groupsJson);
      final assignments = jsonDecode(row.accountGroupIdsJson);
      if (groups is! List ||
          assignments is! Map ||
          assignments.keys.any((id) => id is! String) ||
          assignments.values.any((id) => id is! String)) {
        throw const FormatException('Invalid account organization.');
      }
      return AssetView(
        id: row.id,
        name: row.name,
        accountIds: accounts,
        sortOrder: row.sortOrder,
        version: row.version,
        groups: [for (final value in groups) _group(value)],
        accountGroupIds: assignments.cast<String, String>(),
      );
    } on Exception catch (error, stackTrace) {
      throw InfrastructureException(
        AnalyticsErrorCode.invalidConfiguration,
        cause: error is FormatException
            ? const FormatException('Invalid asset view configuration.')
            : error,
        stackTrace: stackTrace,
      );
    }
  }

  List<String> _strings(Object? value) {
    if (value is! List || value.any((id) => id is! String)) {
      throw const FormatException('Invalid identifiers.');
    }
    return value.cast<String>();
  }

  AssetViewGroup _group(Object? value) {
    if (value is! Map || value['id'] is! String || value['name'] is! String) {
      throw const FormatException('Invalid account group.');
    }
    return AssetViewGroup(
      id: value['id'] as String,
      name: value['name'] as String,
    );
  }
}
