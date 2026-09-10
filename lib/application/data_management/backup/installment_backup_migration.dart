import 'backup_models.dart';
import '../../../core/time/date_label.dart';

/// 旧快照只在导入入口升级；当前合同行不包含阶段参数。
void migrateInstallmentBackup(
  Map<String, Iterable<BackupJson>> tables, {
  required int schemaVersion,
  required int formatVersion,
}) {
  if (schemaVersion < 36) {
    tables.putIfAbsent('lpr_quotes', () => <BackupJson>[]);
    tables.putIfAbsent('installment_repricing_records', () => <BackupJson>[]);
    tables['installment_schedules'] = [
      for (final row in tables['installment_schedules'] ?? <BackupJson>[])
        {
          ...row,
          'manuallyAdjusted':
              row['manuallyAdjusted'] ?? row['status'] == 'pending',
        },
    ];
  }
  if (schemaVersion < 37) {
    tables['reference_rates'] = [
      for (final row in tables.remove('lpr_quotes') ?? <BackupJson>[])
        {
            ...row,
            'type': _legacyReferenceRateType(row['tenor']),
            'rateDate': row['quoteDate'],
          }
          ..remove('tenor')
          ..remove('quoteDate'),
    ];
  }
  if (schemaVersion < 34) {
    tables['installment_contracts'] = [
      for (final row in tables['installment_contracts'] ?? <BackupJson>[])
        {...row, 'name': row['name'] ?? _contractDateName(row)},
    ];
  }
  if (schemaVersion < 31 && tables.containsKey('repayments')) {
    // 与数据库 v31 迁移一致：交易时间优先，其次已有还款时间，最后创建时间。
    final transactionDates = {
      for (final row in tables['transactions'] ?? <BackupJson>[])
        row['id']: row['occurredAt'],
    };
    tables['repayments'] = [
      for (final row in tables['repayments'] ?? <BackupJson>[])
        {
          ...row,
          'repaymentDate':
              transactionDates[row['transactionId']] ??
              row['repaymentDate'] ??
              row['createdAt'],
        },
    ];
  }
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
  if (schemaVersion < 38) {
    tables['installment_stage_configs'] = [
      for (final row in tables['installment_stage_configs'] ?? <BackupJson>[])
        if (row.containsKey('lprTenor'))
          {
            ...row,
            'referenceRateType': row['lprTenor'] == null
                ? null
                : _legacyReferenceRateType(row['lprTenor']),
          }..remove('lprTenor')
        else
          row,
    ];
    tables['installment_repricing_records'] = [
      for (final row
          in tables['installment_repricing_records'] ?? <BackupJson>[])
        {
            ...row,
            'referenceRateType': _legacyReferenceRateType(row['tenor']),
            'referenceRateDate': row['quoteDate'],
            'referenceRatePpm': row['lprPpm'],
          }
          ..remove('tenor')
          ..remove('quoteDate')
          ..remove('lprPpm'),
    ];
  }
}

String _legacyReferenceRateType(Object? tenor) => switch (tenor) {
  'oneYear' => 'lprOneYear',
  'fiveYearPlus' => 'lprFiveYearPlus',
  _ => throw const BackupValidationException('旧 LPR 品种无效'),
};

String _contractDateName(BackupJson row) {
  final value = row['borrowingDate'];
  if (value is! int) throw const BackupValidationException('合同缺少有效借款日期');
  return formatCompactDate(DateTime.fromMillisecondsSinceEpoch(value));
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
