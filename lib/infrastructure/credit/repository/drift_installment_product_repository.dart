import 'package:drift/drift.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../domain/credit/entity/installment_product.dart';
import '../../../domain/credit/port/installment_product_repository.dart';
import '../../database/app_database.dart';
import '../mapper/installment_stage_mapper.dart';

class DriftInstallmentProductRepository
    implements InstallmentProductRepository {
  const DriftInstallmentProductRepository(this.database);
  final AppDatabase database;

  @override
  Future<List<InstallmentProduct>> list() async {
    final rows = await (database.select(
      database.installmentProducts,
    )..orderBy([(r) => OrderingTerm.asc(r.name)])).get();
    return Future.wait(rows.map(_map));
  }

  @override
  Future<InstallmentProduct?> find(String id) async {
    final row = await (database.select(
      database.installmentProducts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<InstallmentProduct> _map(InstallmentProductRow row) async {
    final stages =
        await (database.select(database.installmentStageConfigs)
              ..where(
                (r) => r.ownerType.equals('product') & r.ownerId.equals(row.id),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.position)]))
            .get();
    return InstallmentProduct(
      id: row.id,
      name: row.name,
      archived: row.archived,
      dayCount: decodeDayCount(row.dayCount),
      rounding: RoundingMode.values.byName(row.rounding),
      createdAt: row.createdAt,
      stages: stages.map(decodeProductStage).toList(),
    );
  }

  @override
  Future<void> save(InstallmentProduct product) async {
    await database
        .into(database.installmentProducts)
        .insertOnConflictUpdate(
          InstallmentProductsCompanion.insert(
            id: product.id,
            name: product.name,
            archived: Value(product.archived),
            dayCount: Value(encodeDayCount(product.dayCount)),
            rounding: Value(product.rounding.name),
            createdAt: Value(product.createdAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await (database.delete(database.installmentStageConfigs)..where(
          (r) => r.ownerType.equals('product') & r.ownerId.equals(product.id),
        ))
        .go();
    await database.batch(
      (batch) => batch.insertAll(database.installmentStageConfigs, [
        for (var i = 0; i < product.stages.length; i++)
          encodeProductStage(product.stages[i], product.id, i),
      ]),
    );
  }

  @override
  Future<bool> isUsed(String id) async =>
      (await (database.select(database.installmentContracts)
                ..where((r) => r.productId.equals(id))
                ..limit(1))
              .get())
          .isNotEmpty;

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.installmentStageConfigs,
    )..where((r) => r.ownerType.equals('product') & r.ownerId.equals(id))).go();
    await (database.delete(
      database.installmentProducts,
    )..where((r) => r.id.equals(id))).go();
  }
}
