import 'package:smartflow/application/data_management/backup/backup_models.dart';

/// Historical backups contain the old columns even when the test starts with a
/// current database. Build that historical representation before migrating it.
Map<String, Iterable<BackupJson>> legacyInstallmentSnapshot(
  BackupSnapshot snapshot, {
  bool stageRepricing = false,
}) {
  final tables = <String, Iterable<BackupJson>>{...snapshot.tables};
  final configs = snapshot.rows('installment_repricing_configs');
  tables['installment_stage_configs'] = [
    for (final product in [true, false])
      for (final row in snapshot.rows(
        product
            ? 'installment_product_stage_configs'
            : 'installment_stage_configs',
      ))
        {
          ...row,
          'ownerType': product ? 'product' : 'contract',
          'ownerId': row[product ? 'productId' : 'contractId'],
          'ratePpm': product ? null : row['initialRatePpm'],
          'untilDate': !product && row['stageKind'] == 'deferment'
              ? row['endDate']
              : null,
          'lastDate': !product && row['stageKind'] == 'repayment'
              ? row['endDate']
              : null,
          'repricingPaymentTiming': switch (row['inPeriodRepricingPolicy']) {
            'preservePrincipal' => 'nextPeriod',
            'dynamicPeriodRate' => 'currentPeriod',
            _ => null,
          },
          'referenceRateType': null,
          'spreadBp': null,
          'firstResetDate': null,
          'firstEffectiveDate': null,
          'repricingCycleMonths': null,
          if (stageRepricing && !product)
            for (final config
                in configs
                    .where((config) => config['stageId'] == row['id'])
                    .take(1)) ...{
              'referenceRateType': config['referenceRateType'],
              'spreadBp': config['spreadBp'],
              'firstResetDate': config['firstResetDate'],
              'firstEffectiveDate': config['firstEffectiveDate'],
              'repricingCycleMonths': config['cycleMonths'],
            },
        }..removeWhere(
          (key, _) => const {
            'productId',
            'contractId',
            'rateType',
            'initialRatePpm',
            'endDate',
            'inPeriodRepricingPolicy',
            'tailDifference',
          }.contains(key),
        ),
  ];
  tables.remove('installment_product_stage_configs');
  tables['installment_products'] = [
    for (final row in snapshot.rows('installment_products'))
      {...row, 'tailDifference': 'lastPeriod'},
  ];
  tables['installment_contracts'] = [
    for (final row in snapshot.rows('installment_contracts'))
      {
        ...row,
        'productId': null,
        'productName': null,
        'customRules': true,
        'tailDifference': 'lastPeriod',
      },
  ];
  return tables;
}
