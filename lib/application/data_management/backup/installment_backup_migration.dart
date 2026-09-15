import 'backup_models.dart';
import '../../../core/time/date_label.dart';
import '../../../domain/credit/valobj/repayment_dates_strategy.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../domain/credit/valobj/floating_rate.dart';

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
            'type': _legacyInterestRateType(row['tenor']),
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
                : _legacyInterestRateType(row['lprTenor']),
          }..remove('lprTenor')
        else
          row,
    ];
    tables['installment_repricing_records'] = [
      for (final row
          in tables['installment_repricing_records'] ?? <BackupJson>[])
        {
            ...row,
            'referenceRateType': _legacyInterestRateType(row['tenor']),
            'referenceRateDate': row['quoteDate'],
            'referenceRatePpm': row['lprPpm'],
          }
          ..remove('tenor')
          ..remove('quoteDate')
          ..remove('lprPpm'),
    ];
  }
  if (schemaVersion < 39) {
    tables['installment_repricing_records'] = [
      for (final row
          in tables['installment_repricing_records'] ?? <BackupJson>[])
        {...row, 'status': row['applied'] == true ? 'applied' : 'pending'}
          ..remove('applied'),
    ];
  }
  if (schemaVersion < 40) _migrateContractOperations(tables);
  if (schemaVersion < 41) _migrateRepricingStageScope(tables);
  if (schemaVersion < 42) _splitProductStages(tables);
  if (schemaVersion < 43) _migrateRepricingGenerationDates(tables);
  if (schemaVersion < 44) {
    tables['installment_repricing_configs'] = [
      for (final row
          in tables['installment_repricing_configs'] ?? <BackupJson>[])
        {...row, 'generationCompleted': false},
    ];
  }
}

void _migrateRepricingGenerationDates(
  Map<String, Iterable<BackupJson>> tables,
) {
  DateTime date(Object? milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds as int, isUtc: true);
  final migrated = <BackupJson>[];
  for (final row in tables['installment_repricing_configs'] ?? <BackupJson>[]) {
    if (row['lastGeneratedDate'] == null) {
      migrated.add(row);
      continue;
    }
    final rule = FloatingRateRule(
      referenceRateType: InterestRateType.values.byName(
        row['referenceRateType'] as String,
      ),
      spreadBp: row['spreadBp'] as int,
      firstResetDate: date(row['firstResetDate']),
      firstEffectiveDate: date(row['firstEffectiveDate']),
      cycleMonths: row['cycleMonths'] as int,
    );
    rule.validate();
    final index = rule.effectiveCycleOnOrBefore(date(row['lastGeneratedDate']));
    final reset = index == null ? null : rule.resetDate(index);
    migrated.add({
      ...row,
      'lastGeneratedDate':
          reset == null || reset.isBefore(date(row['effectiveFrom']))
          ? null
          : reset.millisecondsSinceEpoch,
    });
  }
  tables['installment_repricing_configs'] = migrated;
}

void _splitProductStages(Map<String, Iterable<BackupJson>> tables) {
  final products = {
    for (final row in tables['installment_products'] ?? <BackupJson>[])
      row['id']: row,
  };
  final contracts = {
    for (final row in tables['installment_contracts'] ?? <BackupJson>[])
      row['id']: row,
  };
  final productStages = <BackupJson>[];
  final contractStages = <BackupJson>[];
  for (final stage in tables['installment_stage_configs'] ?? <BackupJson>[]) {
    final deferment = stage['stageKind'] == 'deferment';
    final method = stage['repaymentMethod'];
    final policy = method == 'equalInstallment'
        ? switch (stage['repricingPaymentTiming']) {
            null || 'nextPeriod' => 'preservePrincipal',
            'currentPeriod' => 'dynamicPeriodRate',
            _ => throw const BackupValidationException('旧期中重定价策略无效'),
          }
        : null;
    final owner = stage['ownerId'];
    if (stage['ownerType'] == 'product') {
      final product = products[owner];
      if (product == null) throw const BackupValidationException('产品阶段缺少所属产品');
      productStages.add({
        for (final field in [
          'id',
          'position',
          'stageKind',
          'repaymentMethod',
          'intervalMonths',
          'ratePeriod',
          'accrual',
          'amountAlgorithm',
          'createdAt',
          'updatedAt',
        ])
          field: stage[field],
        'productId': owner,
        'rateType': !deferment && method != 'flatFee' && method != 'custom'
            ? 'fixed'
            : null,
        'repricingCycleMonths': null,
        'inPeriodRepricingPolicy': policy,
        'tailDifference': deferment ? null : product['tailDifference'],
      });
    } else if (stage['ownerType'] == 'contract') {
      final contract = contracts[owner];
      if (contract == null) throw const BackupValidationException('合同阶段缺少所属合同');
      final end = deferment
          ? _backupDate(stage, 'untilDate')
          : IntervalRepaymentDates(
              firstDate: _backupDate(stage, 'firstDate'),
              count: stage['periods'] as int,
              intervalMonths: stage['intervalMonths'] as int? ?? 1,
              lastDate: stage['lastDate'] == null
                  ? null
                  : _backupDate(stage, 'lastDate'),
            ).getDates().last;
      contractStages.add(
        {
          ...stage,
          'contractId': owner,
          'endDate': end.millisecondsSinceEpoch,
          'initialRatePpm': stage['ratePpm'],
          'inPeriodRepricingPolicy': policy,
          'tailDifference': deferment ? null : contract['tailDifference'],
        }..removeWhere(
          (key, _) => const {
            'ownerType',
            'ownerId',
            'untilDate',
            'lastDate',
            'ratePpm',
            'referenceRateType',
            'spreadBp',
            'firstResetDate',
            'firstEffectiveDate',
            'repricingCycleMonths',
            'repricingPaymentTiming',
          }.contains(key),
        ),
      );
    } else {
      throw const BackupValidationException('旧阶段归属类型无效');
    }
  }
  tables['installment_product_stage_configs'] = productStages;
  tables['installment_stage_configs'] = contractStages;
  tables['installment_products'] = [
    for (final row in products.values) {...row}..remove('tailDifference'),
  ];
  tables['installment_contracts'] = [
    for (final row in contracts.values)
      {...row}..removeWhere(
        (key, _) => const {
          'productId',
          'productName',
          'customRules',
          'tailDifference',
        }.contains(key),
      ),
  ];
}

void _migrateContractOperations(Map<String, Iterable<BackupJson>> tables) {
  final configurations = <BackupJson>[];
  final stages = (tables['installment_stage_configs'] ?? []).toList();
  for (final contract in tables['installment_contracts'] ?? <BackupJson>[]) {
    if (!stages.any(
      (stage) =>
          stage['ownerType'] == 'contract' &&
          stage['ownerId'] == contract['id'] &&
          stage['referenceRateType'] != null,
    )) {
      continue;
    }
    var start = _backupDate(contract, 'borrowingDate');
    final owned =
        stages
            .where(
              (stage) =>
                  stage['ownerType'] == 'contract' &&
                  stage['ownerId'] == contract['id'],
            )
            .toList()
          ..sort(
            (a, b) => (a['position'] as int).compareTo(b['position'] as int),
          );
    for (final stage in owned) {
      if (stage['stageKind'] == 'deferment') {
        start = _backupDate(stage, 'untilDate');
        continue;
      }
      if (stage['referenceRateType'] != null) {
        configurations.add({
          'id': '${stage['id']}:repricing',
          'contractId': contract['id'],
          'stageId': stage['id'],
          'effectiveFrom': referenceDate(
            stage['accrualStartDate'] == null
                ? start
                : _backupDate(stage, 'accrualStartDate'),
          ).millisecondsSinceEpoch,
          'referenceRateType': stage['referenceRateType'],
          'spreadBp': stage['spreadBp'],
          'firstResetDate': referenceDate(
            _backupDate(stage, 'firstResetDate'),
          ).millisecondsSinceEpoch,
          'firstEffectiveDate': referenceDate(
            _backupDate(stage, 'firstEffectiveDate'),
          ).millisecondsSinceEpoch,
          'cycleMonths': stage['repricingCycleMonths'],
          'createdAt': stage['createdAt'] ?? contract['createdAt'],
        });
      }
      start = IntervalRepaymentDates(
        firstDate: _backupDate(stage, 'firstDate'),
        count: stage['periods'] as int,
        lastDate: stage['lastDate'] == null
            ? null
            : _backupDate(stage, 'lastDate'),
        intervalMonths: stage['intervalMonths'] as int? ?? 1,
      ).getDates().last;
    }
  }
  tables['installment_repricing_configs'] = configurations;
  tables['installment_interest_adjustments'] = [];
  tables['installment_stage_configs'] = [
    for (final stage in stages)
      if (stage['referenceRateType'] != null)
        {
          ...stage,
          'referenceRateType': null,
          'spreadBp': null,
          'firstResetDate': null,
          'firstEffectiveDate': null,
          'repricingCycleMonths': null,
        }
      else
        stage,
  ];
  final records = <String, BackupJson>{};
  final originals =
      (tables['installment_repricing_records'] ?? <BackupJson>[]).toList()
        ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
  const ranks = {'pending': 0, 'applied': 1, 'userConfirmed': 2};
  for (final original in originals) {
    final row = {...original};
    final key =
        '${row['contractId']}:${row['stageId']}:${row['effectiveDate']}';
    final previous = records[key];
    if (previous != null &&
        const [
          'resetDate',
          'referenceRateDate',
          'referenceRateType',
          'referenceRatePpm',
          'spreadBp',
          'source',
        ].any((field) => row[field] != previous[field])) {
      throw const BackupValidationException('同一合同同一阶段同一生效日存在冲突的旧重定价快照');
    }
    if (previous == null ||
        (ranks[row['status']] ?? 0) > (ranks[previous['status']] ?? 0)) {
      records[key] = row;
    }
  }
  tables['installment_repricing_records'] = records.values.toList();
  for (final config in configurations) {
    final next = configurations.where(
      (value) =>
          value['contractId'] == config['contractId'] &&
          value['stageId'] == config['stageId'] &&
          (value['effectiveFrom'] as int) > (config['effectiveFrom'] as int),
    );
    final dates =
        records.values
            .where(
              (record) =>
                  record['contractId'] == config['contractId'] &&
                  record['stageId'] == config['stageId'] &&
                  (record['effectiveDate'] as int) >=
                      (config['effectiveFrom'] as int) &&
                  next.every(
                    (value) =>
                        (record['effectiveDate'] as int) <
                        (value['effectiveFrom'] as int),
                  ),
            )
            .map((record) => record['effectiveDate'] as int)
            .toList()
          ..sort();
    config['lastGeneratedDate'] = dates.lastOrNull;
  }
}

void _migrateRepricingStageScope(Map<String, Iterable<BackupJson>> tables) {
  final contracts = {
    for (final row in tables['installment_contracts'] ?? <BackupJson>[])
      row['id']: row,
  };
  final stages = (tables['installment_stage_configs'] ?? <BackupJson>[])
      .toList();
  for (final (table, dateField) in [
    ('installment_repricing_configs', 'effectiveFrom'),
    ('installment_repricing_records', 'effectiveDate'),
  ]) {
    tables[table] = [
      for (final row in tables[table] ?? <BackupJson>[])
        if (row['stageId'] != null)
          row
        else
          {
            ...row,
            'stageId': _legacyOperationStage(row, dateField, contracts, stages),
          },
    ];
  }
}

String _legacyOperationStage(
  BackupJson row,
  String dateField,
  Map<Object?, BackupJson> contracts,
  List<BackupJson> stages,
) {
  final contract = contracts[row['contractId']];
  if (contract == null) throw const BackupValidationException('旧重定价缺少所属合同');
  final owned =
      stages
          .where(
            (stage) =>
                stage['ownerType'] == 'contract' &&
                stage['ownerId'] == row['contractId'] &&
                stage['stageKind'] == 'repayment',
          )
          .toList()
        ..sort(
          (a, b) => (a['position'] as int).compareTo(b['position'] as int),
        );
  if (dateField == 'effectiveFrom') {
    for (final stage in owned) {
      if (row['id'] == '${stage['id']}:repricing') return stage['id'] as String;
    }
  }
  final date = referenceDate(_backupDate(row, dateField));
  if (!date.isBefore(referenceDate(_backupDate(contract, 'borrowingDate')))) {
    for (final stage in owned) {
      final end = referenceDate(
        IntervalRepaymentDates(
          firstDate: _backupDate(stage, 'firstDate'),
          count: stage['periods'] as int,
          lastDate: stage['lastDate'] == null
              ? null
              : _backupDate(stage, 'lastDate'),
          intervalMonths: stage['intervalMonths'] as int? ?? 1,
        ).getDates().last,
      );
      if (date.isBefore(end)) return stage['id'] as String;
    }
  }
  throw const BackupValidationException('旧重定价无法确定所属阶段');
}

DateTime _backupDate(BackupJson row, String field) {
  final value = row[field];
  if (value is! int) throw BackupValidationException('旧合同缺少有效日期 $field');
  return DateTime.fromMillisecondsSinceEpoch(value);
}

String _legacyInterestRateType(Object? tenor) => switch (tenor) {
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
