import 'backup_models.dart';

/// 旧快照只在导入入口升级；当前合同行不包含阶段参数。
void migrateInstallmentBackup(
  Map<String, Iterable<BackupJson>> tables, {
  required int schemaVersion,
  required int formatVersion,
}) {
  if (schemaVersion < 32 && formatVersion < 2) {
    _upgradeSingleStageSnapshot(tables);
  }
  if (schemaVersion < 33) {
    tables['installment_stage_configs'] = [
      for (final stage in tables['installment_stage_configs'] ?? <BackupJson>[])
        if (stage['ownerType'] == 'contract' &&
            stage['repaymentMethod'] == 'flatFee' &&
            stage['periods'] is int &&
            (stage['periods'] as int) > 1)
          {
            ...stage,
            'repaymentMethod': 'equalPrincipal',
            'ratePeriod': null,
            'ratePpm': null,
          }
        else
          stage,
    ];
    tables['installment_contracts'] = [
      for (final original in tables['installment_contracts'] ?? <BackupJson>[])
        {...original}..removeWhere(
          (key, value) => const {
            'totalPeriods',
            'firstRepaymentDate',
            'lastRepaymentDate',
            'repaymentMethod',
            'interestRatePeriod',
            'interestRatePpm',
            'interestAccrualMethod',
            'totalFeeMinor',
          }.contains(key),
        ),
    ];
  }
}

void _upgradeSingleStageSnapshot(Map<String, Iterable<BackupJson>> tables) {
  tables.putIfAbsent('installment_products', () => []);
  if (!tables.containsKey('installment_stage_configs')) {
    tables['installment_stage_configs'] = [
      for (final c in tables['installment_contracts'] ?? <BackupJson>[])
        <String, Object?>{
          'id': '${c['id']}:stage:1',
          'ownerType': 'contract',
          'ownerId': c['id'],
          'position': 0,
          'stageKind': 'repayment',
          'repaymentMethod': c['repaymentMethod'],
          'intervalMonths': 1,
          'ratePeriod': c['interestRatePeriod'],
          'accrual': c['interestAccrualMethod'],
          'amountAlgorithm': c['repaymentMethod'] == 'equalInstallment'
              ? 'actualRate'
              : null,
          'periods': c['totalPeriods'],
          'ratePpm': c['interestRatePpm'],
          'feeMinor': c['totalFeeMinor'],
          'firstDate': c['firstRepaymentDate'],
          'lastDate': c['lastRepaymentDate'],
          'createdAt': c['createdAt'],
          'updatedAt': c['updatedAt'],
          'endPrincipalMinor': null,
          'fixedAmountMinor': null,
          'untilDate': null,
          'accrualStartDate': null,
        },
    ];
  }
  tables['installment_contracts'] = [
    for (final c in tables['installment_contracts'] ?? <BackupJson>[])
      {
        ...c,
        'productId': null,
        'productName': null,
        'customRules': false,
        'dayCount': 'thirty360',
        'rounding': 'halfUp',
        'tailDifference': 'lastPeriod',
      },
  ];
  tables['installment_schedules'] = [
    for (final r in tables['installment_schedules'] ?? <BackupJson>[])
      {...r, 'stageId': '${r['contractId']}:stage:1'},
  ];
}
