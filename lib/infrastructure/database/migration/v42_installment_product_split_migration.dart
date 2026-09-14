import 'package:drift/drift.dart';

import '../app_database.dart';
import 'v41_installment_schema.dart';

/// Splits reusable product rules from contract terms without changing stage IDs.
Future<void> migrateInstallmentProductSplit(
  AppDatabase database,
  Migrator migrator,
) => database.transaction(() async {
  final columns = await database
      .customSelect('PRAGMA table_info(installment_stage_configs)')
      .get();
  if (!columns.any((row) => row.read<String>('name') == 'owner_type')) return;

  final products = {
    for (final row
        in await database
            .customSelect('SELECT * FROM installment_products')
            .get())
      row.read<String>('id'): row,
  };
  final contracts = {
    for (final row
        in await database
            .customSelect('SELECT * FROM installment_contracts')
            .get())
      row.read<String>('id'): row,
  };
  final stages = await database
      .customSelect(
        'SELECT * FROM installment_stage_configs ORDER BY owner_type, owner_id, position',
      )
      .get();
  await migrator.createTable(database.installmentProductStageConfigs);
  for (final stage in stages.where(
    (row) => row.read<String>('owner_type') == 'product',
  )) {
    final productId = stage.read<String>('owner_id');
    final product = products[productId];
    if (product == null) throw StateError('产品阶段缺少所属产品，升级已回滚');
    final deferment = stage.read<String>('stage_kind') == 'deferment';
    final method = stage.readNullable<String>('repayment_method');
    final interest = !deferment && method != 'flatFee' && method != 'custom';
    await database
        .into(database.installmentProductStageConfigs)
        .insert(
          InstallmentProductStageConfigsCompanion.insert(
            id: stage.read<String>('id'),
            productId: productId,
            position: stage.read<int>('position'),
            stageKind: stage.read<String>('stage_kind'),
            repaymentMethod: Value(
              stage.readNullable<String>('repayment_method'),
            ),
            intervalMonths: Value(stage.readNullable<int>('interval_months')),
            rateType: Value(interest ? 'fixed' : null),
            ratePeriod: Value(stage.readNullable<String>('rate_period')),
            accrual: Value(stage.readNullable<String>('accrual')),
            amountAlgorithm: Value(
              stage.readNullable<String>('amount_algorithm'),
            ),
            inPeriodRepricingPolicy: Value(
              method == 'equalInstallment'
                  ? migrateInPeriodRepricingPolicy(
                      stage.readNullable<String>('repricing_payment_timing'),
                    )
                  : null,
            ),
            tailDifference: Value(
              deferment ? null : product.read<String>('tail_difference'),
            ),
            createdAt: Value(legacyInstallmentDate(stage, 'created_at')),
            updatedAt: Value(legacyInstallmentDate(stage, 'updated_at')),
          ),
        );
  }
  for (final definition in [
    'contract_id TEXT',
    'end_date INTEGER',
    'initial_rate_ppm INTEGER',
    'in_period_repricing_policy TEXT',
    'tail_difference TEXT',
  ]) {
    await database.customStatement(
      'ALTER TABLE installment_stage_configs ADD COLUMN $definition',
    );
  }
  for (final stage in stages.where(
    (row) => row.read<String>('owner_type') != 'product',
  )) {
    if (stage.read<String>('owner_type') != 'contract') {
      throw StateError('阶段归属类型无效，升级已回滚');
    }
    final contractId = stage.read<String>('owner_id');
    final contract = contracts[contractId];
    if (contract == null) throw StateError('合同阶段缺少所属合同，升级已回滚');
    final deferment = stage.read<String>('stage_kind') == 'deferment';
    final equal =
        stage.readNullable<String>('repayment_method') == 'equalInstallment';
    await database.customStatement(
      '''
      UPDATE installment_stage_configs SET contract_id = ?, end_date = ?,
        initial_rate_ppm = rate_ppm, in_period_repricing_policy = ?, tail_difference = ?
      WHERE id = ?
    ''',
      [
        contractId,
        legacyInstallmentStageEnd(stage).millisecondsSinceEpoch ~/ 1000,
        equal
            ? migrateInPeriodRepricingPolicy(
                stage.readNullable<String>('repricing_payment_timing'),
              )
            : null,
        deferment ? null : contract.read<String>('tail_difference'),
        stage.read<String>('id'),
      ],
    );
  }
  await database.customStatement(
    "DELETE FROM installment_stage_configs WHERE owner_type = 'product'",
  );
  await migrator.alterTable(TableMigration(database.installmentStageConfigs));
  await migrator.alterTable(TableMigration(database.installmentProducts));
  await migrator.alterTable(
    TableMigration(
      database.installmentContracts,
      columnTransformer: {
        database.installmentContracts.borrowingDate:
            const CustomExpression<DateTime>('start_date'),
      },
    ),
  );
});
