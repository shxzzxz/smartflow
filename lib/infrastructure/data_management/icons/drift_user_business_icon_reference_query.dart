import 'package:drift/drift.dart';

import '../../../application/data_management/icons/query/port/user_business_icon_reference_query.dart';
import '../../database/app_database.dart';

class DriftUserBusinessIconReferenceQuery
    implements UserBusinessIconReferenceQuery {
  const DriftUserBusinessIconReferenceQuery(this._database);

  final AppDatabase _database;

  @override
  Future<Map<String, int>> countByRef() async {
    final rows = await (_database.select(
      _database.accounts,
    )..where((row) => row.iconKey.like('user:%'))).get();
    final counts = <String, int>{};
    for (final row in rows) {
      final ref = row.iconKey?.trim();
      if (ref == null || ref.isEmpty) continue;
      counts.update(ref, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
