import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'backup_models.dart';
import 'installment_backup_migration.dart';

abstract interface class BackupSnapshotGateway {
  int get schemaVersion;

  Future<BackupSnapshot> readSnapshot();

  Future<void> replaceSnapshot(BackupSnapshot snapshot);
}

abstract interface class BackupRestoreCoordinator {
  Future<T> runRestoreExclusive<T>(Future<T> Function() action);
}

class BackupInspection {
  const BackupInspection({required this.manifest, required this.snapshot});

  final BackupManifest manifest;
  final BackupSnapshot snapshot;
}

/// Application use case for exporting, inspecting, comparing, and restoring a
/// SmartFlow logical backup directory.
class BackupService {
  static const _maxRowsPerFile = 10000;

  BackupService({
    required BackupSnapshotGateway gateway,
    required BackupPackageStore packageStore,
    this.appVersion = 'unknown',
    this.baseCurrency = 'CNY',
    this.minorUnit = 2,
    Uuid? idGenerator,
  }) : _gateway = gateway,
       _packageStore = packageStore,
       _idGenerator = idGenerator ?? const Uuid();

  final BackupSnapshotGateway _gateway;
  final BackupPackageStore _packageStore;
  final String appVersion;
  final String baseCurrency;
  final int minorUnit;
  final Uuid _idGenerator;

  Future<BackupManifest> createBackup(
    Object destination, {
    DateTime? createdAt,
  }) async {
    final snapshot = await _gateway.readSnapshot();
    validateSnapshot(snapshot);
    final descriptors = <BackupFileDescriptor>[];
    final files = <String, Uint8List>{};
    for (final table in BackupTables.all) {
      final rows = snapshot.rows(table);
      final chunks = <List<BackupJson>>[];
      for (var start = 0; start < rows.length; start += _maxRowsPerFile) {
        final end = start + _maxRowsPerFile < rows.length
            ? start + _maxRowsPerFile
            : rows.length;
        chunks.add(rows.sublist(start, end));
      }
      if (chunks.isEmpty) chunks.add(const []);
      for (var index = 0; index < chunks.length; index++) {
        final suffix = chunks.length == 1
            ? '$table.ndjson'
            : '$table-${(index + 1).toString().padLeft(4, '0')}.ndjson';
        final relativePath = '${BackupTables.sectionFor(table)}/$suffix';
        final bytes = _encodeNdjson(chunks[index]);
        files[relativePath] = bytes;
        descriptors.add(
          BackupFileDescriptor(
            path: relativePath,
            table: table,
            rowCount: chunks[index].length,
            byteCount: bytes.length,
            sha256: sha256.convert(bytes).toString(),
          ),
        );
      }
    }
    final preferencesBytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(snapshot.preferences),
      ),
    );
    files['preferences.json'] = preferencesBytes;
    descriptors.add(
      BackupFileDescriptor(
        path: 'preferences.json',
        table: 'preferences',
        rowCount: snapshot.preferences.length,
        byteCount: preferencesBytes.length,
        sha256: sha256.convert(preferencesBytes).toString(),
      ),
    );

    final manifest = BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      appVersion: appVersion,
      schemaVersion: _gateway.schemaVersion,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      baseCurrency: baseCurrency.toUpperCase(),
      minorUnit: minorUnit,
      backupId: _idGenerator.v4(),
      files: List.unmodifiable(descriptors),
    );
    await _packageStore.write(
      destination,
      BackupPackage(manifest: manifest, files: files),
    );
    return manifest;
  }

  Future<BackupInspection> inspect(Object source) async {
    final package = await _packageStore.read(source);
    final manifest = package.manifest;
    if (manifest.schemaVersion > _gateway.schemaVersion) {
      throw BackupValidationException(
        '备份 schema ${manifest.schemaVersion} 高于当前数据库 schema ${_gateway.schemaVersion}。',
      );
    }
    final tables = <String, Iterable<BackupJson>>{};
    var hasPreferences = false;
    for (final descriptor in manifest.files) {
      final bytes = package.files[descriptor.path];
      if (bytes == null) {
        throw BackupValidationException('备份缺少文件: ${descriptor.path}');
      }
      if (bytes.length != descriptor.byteCount) {
        throw BackupValidationException('文件大小校验失败: ${descriptor.path}');
      }
      if (sha256.convert(bytes).toString().toLowerCase() != descriptor.sha256) {
        throw BackupValidationException('文件完整性校验失败: ${descriptor.path}');
      }
      if (descriptor.table == 'preferences') {
        if (hasPreferences) {
          throw const BackupValidationException('备份重复包含 preferences.json。');
        }
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map) {
          throw const BackupValidationException('preferences.json 必须是对象。');
        }
        if (decoded.length != descriptor.rowCount) {
          throw BackupValidationException('preferences.json 行数校验失败。');
        }
        if (decoded.keys.any((key) => key is! String)) {
          throw const BackupValidationException('preferences.json 键必须是字符串。');
        }
        tables['preferences'] = [
          {
            for (final entry in decoded.entries)
              entry.key as String: entry.value,
          },
        ];
        hasPreferences = true;
        continue;
      }
      final rows = _decodeNdjson(bytes, descriptor.path);
      if (rows.length != descriptor.rowCount) {
        throw BackupValidationException('文件行数校验失败: ${descriptor.path}');
      }
      final existing = tables[descriptor.table];
      tables[descriptor.table] = existing == null
          ? rows
          : [...existing, ...rows];
    }
    if (!hasPreferences) {
      throw const BackupValidationException('备份缺少 preferences.json。');
    }
    migrateInstallmentBackup(
      tables,
      schemaVersion: manifest.schemaVersion,
      formatVersion: manifest.formatVersion,
    );
    for (final table in BackupTables.all) {
      if (!tables.containsKey(table)) {
        throw BackupValidationException('备份缺少业务表文件: $table');
      }
    }
    final preferences = (tables.remove('preferences')!.single);
    final snapshot = BackupSnapshot(tables: tables, preferences: preferences);
    validateSnapshot(snapshot);
    return BackupInspection(manifest: manifest, snapshot: snapshot);
  }

  Future<BackupDiff> compare(Object source) async {
    final inspection = await inspect(source);
    final current = await _gateway.readSnapshot();
    return BackupDiff.compare(current, inspection.snapshot);
  }

  Future<BackupDiff> restore(Object source) async {
    Future<BackupDiff> operation() async {
      final inspection = await inspect(source);
      final current = await _gateway.readSnapshot();
      final normalized = recomputeBalances(inspection.snapshot);
      final diff = BackupDiff.compare(current, normalized);
      if (diff.isNoop) return diff;
      await _gateway.replaceSnapshot(normalized);
      return diff;
    }

    if (_gateway is BackupRestoreCoordinator) {
      return (_gateway as BackupRestoreCoordinator).runRestoreExclusive(
        operation,
      );
    }
    return operation();
  }

  /// Rebuilds account balances from entries before handing a snapshot to the
  /// persistence gateway. The serialized balance is still validated first so
  /// corruption cannot be silently hidden during restore.
  static BackupSnapshot recomputeBalances(BackupSnapshot snapshot) {
    validateSnapshot(snapshot);
    final accounts = snapshot.rows('accounts');
    final accountTypes = {
      for (final row in accounts) '${row['id']}': row['accountType'],
    };
    final balances = <String, int>{};
    for (final row in snapshot.rows('entries')) {
      final amount = _int(row['amountMinor'], 'entries.amountMinor');
      final accountId = '${row['accountId']}';
      final type = accountTypes[accountId];
      final positive = type == 'asset' || type == 'expense'
          ? row['direction'] == 'debit'
          : row['direction'] == 'credit';
      balances[accountId] =
          (balances[accountId] ?? 0) + (positive ? amount : -amount);
    }
    return snapshot.copyWith(
      tables: {
        ...snapshot.tables,
        'accounts': [
          for (final row in accounts)
            {...row, 'balanceMinor': balances['${row['id']}'] ?? 0},
        ],
      },
    );
  }

  static void validateSnapshot(BackupSnapshot snapshot) {
    _validateWireCodes(snapshot);
    for (final table in BackupTables.all) {
      _indexByIdentity(snapshot.rows(table), table);
    }
    final accounts = _index(snapshot.rows('accounts'));
    final groups = _index(snapshot.rows('account_groups'));
    final transactions = _index(snapshot.rows('transactions'));
    final tags = _index(snapshot.rows('tags'));
    final contracts = _index(snapshot.rows('installment_contracts'));
    final products = _index(snapshot.rows('installment_products'));
    final stages = _index(snapshot.rows('installment_stage_configs'));
    _validateInstallmentStages(snapshot, contracts, products, stages);
    final bills = _index(snapshot.rows('bills'));
    final billItems = _index(snapshot.rows('bill_items'));
    final schedules = _index(snapshot.rows('installment_schedules'));
    final repayments = _index(snapshot.rows('repayments'));
    final importBatches = _index(snapshot.rows('import_batches'));

    for (final row in snapshot.rows('accounts')) {
      _optionalReference(row, 'groupId', groups, 'accounts.groupId');
      _optionalReference(row, 'parentId', accounts, 'accounts.parentId');
    }
    final accountParents = <String, String>{};
    for (final row in snapshot.rows('accounts')) {
      final parent = row['parentId'];
      if (parent is String) accountParents['${row['id']}'] = parent;
    }
    for (final id in accountParents.keys) {
      final seen = <String>{};
      var cursor = id;
      while (accountParents.containsKey(cursor)) {
        if (!seen.add(cursor)) {
          throw const BackupValidationException('账户父子关系存在循环引用。');
        }
        cursor = accountParents[cursor]!;
      }
    }
    for (final row in snapshot.rows('transactions')) {
      _optionalReference(
        row,
        'parentTransactionId',
        transactions,
        'transactions.parentTransactionId',
      );
      if (row['ownerId'] != null && row['ownerType'] == 'installment') {
        _requiredReference(row, 'ownerId', contracts, 'transactions.ownerId');
      }
    }
    final transactionParents = <String, String>{};
    for (final row in snapshot.rows('transactions')) {
      final id = '${row['id']}';
      final parent = row['parentTransactionId'];
      if (parent is String) transactionParents[id] = parent;
    }
    for (final id in transactionParents.keys) {
      final seen = <String>{};
      var cursor = id;
      while (transactionParents.containsKey(cursor)) {
        if (!seen.add(cursor)) {
          throw const BackupValidationException('交易父子关系存在循环引用。');
        }
        cursor = transactionParents[cursor]!;
      }
    }
    for (final row in snapshot.rows('transaction_lines')) {
      _requiredReference(
        row,
        'transactionId',
        transactions,
        'transaction_lines.transactionId',
      );
      _optionalReference(
        row,
        'accountId',
        accounts,
        'transaction_lines.accountId',
      );
    }
    for (final row in snapshot.rows('entries')) {
      _requiredReference(
        row,
        'transactionId',
        transactions,
        'entries.transactionId',
      );
      _requiredReference(row, 'accountId', accounts, 'entries.accountId');
    }
    for (final row in snapshot.rows('transaction_tags')) {
      _requiredReference(
        row,
        'transactionId',
        transactions,
        'transaction_tags.transactionId',
      );
      _requiredReference(row, 'tagId', tags, 'transaction_tags.tagId');
    }
    for (final row in snapshot.rows('budgets')) {
      _optionalReference(row, 'accountId', accounts, 'budgets.accountId');
    }
    for (final row in snapshot.rows('credit_liability_accounts')) {
      _requiredReference(
        row,
        'accountId',
        accounts,
        'credit_liability_accounts.accountId',
      );
    }
    for (final row in snapshot.rows('bills')) {
      _requiredReference(row, 'accountId', accounts, 'bills.accountId');
    }
    for (final row in snapshot.rows('bill_items')) {
      _requiredReference(row, 'billId', bills, 'bill_items.billId');
      _optionalReference(row, 'contractId', contracts, 'bill_items.contractId');
      _optionalReference(row, 'scheduleId', schedules, 'bill_items.scheduleId');
      final contractId = row['contractId'];
      final scheduleId = row['scheduleId'];
      if (scheduleId != null) {
        final schedule = schedules['$scheduleId'];
        if (schedule == null ||
            contractId is! String ||
            schedule['contractId'] != contractId) {
          throw const BackupValidationException('账单明细的合同与分期计划关系无效。');
        }
      }
    }
    for (final row in snapshot.rows('bill_generation_suppressions')) {
      _requiredReference(
        row,
        'accountId',
        accounts,
        'bill_generation_suppressions.accountId',
      );
    }
    for (final row in snapshot.rows('installment_contracts')) {
      _requiredReference(
        row,
        'liabilityAccountId',
        accounts,
        'installment_contracts.liabilityAccountId',
      );
      _optionalReference(
        row,
        'disbursementAccountId',
        accounts,
        'installment_contracts.disbursementAccountId',
      );
      _optionalReference(
        row,
        'disbursementTransactionId',
        transactions,
        'installment_contracts.disbursementTransactionId',
      );
      _optionalReference(
        row,
        'sourceRepaymentId',
        repayments,
        'installment_contracts.sourceRepaymentId',
      );
    }
    for (final row in snapshot.rows('installment_schedules')) {
      _requiredReference(
        row,
        'contractId',
        contracts,
        'installment_schedules.contractId',
      );
    }
    for (final row in snapshot.rows('repayments')) {
      _optionalReference(
        row,
        'transactionId',
        transactions,
        'repayments.transactionId',
      );
      final targetType = row['targetType'];
      final target = switch (targetType) {
        'BILL' => bills,
        'CONTRACT' => contracts,
        'ACCOUNT' => accounts,
        _ => null,
      };
      if (target == null) {
        throw BackupValidationException(
          'repayments.targetType 不是稳定 wire code。',
        );
      }
      _requiredReference(row, 'targetId', target, 'repayments.targetId');
    }
    for (final row in snapshot.rows('repayment_items')) {
      _requiredReference(
        row,
        'repaymentId',
        repayments,
        'repayment_items.repaymentId',
      );
      _optionalReference(
        row,
        'billItemId',
        billItems,
        'repayment_items.billItemId',
      );
      final billItemId = row['billItemId'];
      if (billItemId is String) {
        final repayment = repayments['${row['repaymentId']}'];
        final billItem = billItems[billItemId];
        if (repayment == null || billItem == null) {
          throw const BackupValidationException('还款明细关系无效。');
        }
        final targetType = repayment['targetType'];
        final targetId = repayment['targetId'];
        final belongs = switch (targetType) {
          'BILL' => billItem['billId'] == targetId,
          'CONTRACT' => billItem['contractId'] == targetId,
          _ => false,
        };
        if (!belongs) {
          throw const BackupValidationException('还款明细不属于还款目标。');
        }
      }
    }
    for (final row in snapshot.rows('import_batch_items')) {
      _requiredReference(
        row,
        'batchId',
        importBatches,
        'import_batch_items.batchId',
      );
      // Import batch details are historical records. Reverting an import (or
      // manually deleting its top-level transaction) intentionally leaves the
      // detail row behind, so this is a historical identity, not a hard FK.
      _requiredIdentity(
        row,
        'topLevelTransactionId',
        'import_batch_items.topLevelTransactionId',
      );
    }
    for (final row in snapshot.rows('import_entity_mappings')) {
      _requiredReference(
        row,
        'targetAccountId',
        accounts,
        'import_entity_mappings.targetAccountId',
      );
    }

    _validatePostingBalance(snapshot, accounts);
  }

  static void _validateInstallmentStages(
    BackupSnapshot snapshot,
    Map<String, BackupJson> contracts,
    Map<String, BackupJson> products,
    Map<String, BackupJson> stages,
  ) {
    const variableFields = [
      'periods',
      'ratePpm',
      'endPrincipalMinor',
      'fixedAmountMinor',
      'feeMinor',
      'untilDate',
      'firstDate',
      'lastDate',
      'accrualStartDate',
    ];
    final positions = <String>{};
    if (stages.length != snapshot.rows('installment_stage_configs').length ||
        products.length != snapshot.rows('installment_products').length) {
      throw const BackupValidationException('分期产品或阶段标识重复');
    }
    for (final row in [...products.values, ...contracts.values]) {
      if (!const {'thirty360', 'thirty365'}.contains(row['dayCount']) ||
          !const {
            'halfUp',
            'halfEven',
            'down',
            'up',
          }.contains(row['rounding']) ||
          row['tailDifference'] != 'lastPeriod') {
        throw const BackupValidationException('分期计算约定无效');
      }
    }
    for (final c in contracts.values) {
      _optionalReference(
        c,
        'productId',
        products,
        'installment_contracts.productId',
      );
    }
    for (final row in stages.values) {
      final owner = row['ownerType'];
      if (owner != 'product' && owner != 'contract') {
        throw const BackupValidationException('阶段归属类型无效');
      }
      _requiredReference(
        row,
        'ownerId',
        owner == 'product' ? products : contracts,
        'installment_stage_configs.ownerId',
      );
      final position = row['position'];
      if (position is! int ||
          position < 0 ||
          !positions.add('$owner:${row['ownerId']}:$position')) {
        throw const BackupValidationException('阶段顺序无效或重复');
      }
      if (owner == 'product' &&
          variableFields.any((field) => row[field] != null)) {
        throw const BackupValidationException('产品阶段不能包含金额、期数或日期');
      }
      if (row['stageKind'] != 'deferment' && row['stageKind'] != 'repayment') {
        throw const BackupValidationException('阶段类型无效');
      }
      if (row['stageKind'] == 'deferment') {
        if ([
              'repaymentMethod',
              'intervalMonths',
              'ratePeriod',
              'accrual',
              'amountAlgorithm',
              ...variableFields.where((f) => f != 'untilDate'),
            ].any((f) => row[f] != null) ||
            (owner == 'contract' && row['untilDate'] == null)) {
          throw const BackupValidationException('免还阶段配置无效');
        }
      } else {
        if (row['untilDate'] != null) {
          throw const BackupValidationException('还款阶段不能包含免还结束日');
        }
        if (!const {
          'equalInstallment',
          'equalPrincipal',
          'interestFirst',
          'flatFee',
          'custom',
        }.contains(row['repaymentMethod'])) {
          throw const BackupValidationException('阶段还款方式无效');
        }
        if (owner == 'contract' &&
            (row['firstDate'] == null || row['periods'] is! int)) {
          throw const BackupValidationException('合同阶段缺少日期或期数');
        }
        if (row['repaymentMethod'] == 'equalInstallment' &&
            !const {
              'nominalRate',
              'actualRate',
              'fixed',
            }.contains(row['amountAlgorithm'])) {
          throw const BackupValidationException('等额本息固定额算法无效');
        }
        if (owner == 'contract' &&
            row['amountAlgorithm'] == 'fixed' &&
            row['fixedAmountMinor'] == null) {
          throw const BackupValidationException('指定固定额缺少金额');
        }
        if (row['repaymentMethod'] != 'equalInstallment' &&
            (row['amountAlgorithm'] != null ||
                row['fixedAmountMinor'] != null)) {
          throw const BackupValidationException('非等额本息阶段不能指定固定额算法');
        }
        for (final field in [
          'periods',
          'intervalMonths',
          'fixedAmountMinor',
          'ratePpm',
          'endPrincipalMinor',
          'feeMinor',
        ]) {
          final number = row[field];
          final positive = const {
            'periods',
            'intervalMonths',
            'fixedAmountMinor',
          }.contains(field);
          if (number != null &&
              (number is! int || number < (positive ? 1 : 0))) {
            throw BackupValidationException('阶段字段 $field 无效');
          }
        }
        if (row['ratePeriod'] != null &&
                !const {
                  'annual',
                  'monthly',
                  'daily',
                }.contains(row['ratePeriod']) ||
            row['accrual'] != null &&
                !const {
                  'annual',
                  'monthly',
                  'daily',
                }.contains(row['accrual'])) {
          throw const BackupValidationException('阶段利率单位或计息方式无效');
        }
        if (row['ratePpm'] != null && row['ratePeriod'] == null) {
          throw const BackupValidationException('阶段利率缺少单位');
        }
        if (row['repaymentMethod'] != 'flatFee' &&
            (row['intervalMonths'] == null ||
                row['accrual'] == null ||
                owner == 'product' && row['ratePeriod'] == null)) {
          throw const BackupValidationException('阶段计算规则不完整');
        }
      }
    }
    for (final entry in {'product': products, 'contract': contracts}.entries) {
      for (final id in entry.value.keys) {
        final owned =
            stages.values
                .where((s) => s['ownerType'] == entry.key && s['ownerId'] == id)
                .toList()
              ..sort(
                (a, b) =>
                    (a['position'] as int).compareTo(b['position'] as int),
              );
        if (!owned.any((s) => s['stageKind'] == 'repayment') ||
            List.generate(
              owned.length,
              (i) => owned[i]['position'] == i,
            ).contains(false)) {
          throw const BackupValidationException('产品或合同缺少有效的有序阶段');
        }
      }
    }
    for (final row in snapshot.rows('installment_schedules')) {
      _requiredReference(
        row,
        'stageId',
        stages,
        'installment_schedules.stageId',
      );
      final stage = stages[row['stageId']];
      if (stage != null &&
          (stage['ownerType'] != 'contract' ||
              stage['ownerId'] != row['contractId'] ||
              stage['stageKind'] != 'repayment')) {
        throw const BackupValidationException('计划期次与所属合同阶段不一致');
      }
    }
  }

  static void _validateWireCodes(BackupSnapshot snapshot) {
    const codes = <String, Set<String>>{
      'accountType': {'asset', 'liability', 'equity', 'income', 'expense'},
      'accountSubtype': {'fund', 'receivable', 'payable', 'loan'},
      'accountSource': {'builtin', 'user', 'import'},
      'businessPurpose': {
        'dailyExpense',
        'dailyIncome',
        'transfer',
        'refund',
        'reimbursementAdvance',
        'reimbursementReceipt',
        'reimbursementClose',
        'debtRepayment',
        'borrowing',
        'lending',
        'receivableCollection',
        'badDebt',
        'debtRelief',
        'openingBalance',
        'balanceAdjustment',
      },
      'sourceKind': {'manual', 'import', 'auto'},
      'transactionRole': {
        'category',
        'settlementIn',
        'settlementOut',
        'receivable',
        'liability',
        'interest',
        'fee',
        'discount',
        'refundOffset',
        'reimbursementExpenseCategory',
        'reimbursementGapIncome',
        'reimbursementGapExpense',
        'openingBalance',
        'balanceAdjustment',
      },
      'direction': {'debit', 'credit'},
      'creditLiabilityKind': {'credit', 'loan'},
      'billStatus': {'open', 'billed', 'settled'},
      'billItemType': {'consumption', 'installment'},
      'billItemStatus': {'pending', 'partiallyPaid', 'paid', 'skipped'},
      'installmentSourceType': {'disbursement', 'billConversion'},
      'repaymentMethod': {
        'equalInstallment',
        'equalPrincipal',
        'interestFirst',
        'flatFee',
        'custom',
      },
      'interestRatePeriod': {'annual', 'monthly', 'daily'},
      'interestAccrualMethod': {'daily', 'monthly', 'annual'},
      'contractStatus': {'active', 'settled'},
      'scheduleStatus': {'pending', 'partiallyPaid', 'paid', 'skipped'},
      'importSource': {'yimu'},
      'importEntityKind': {'account', 'category'},
      'importBatchStatus': {'imported', 'reverted'},
      'repaymentType': {'BILL', 'INSTALLMENT', 'PREPAYMENT', 'UNATTRIBUTED'},
    };
    void check(
      BackupJson row,
      String key,
      String code, {
      bool nullable = false,
    }) {
      final value = row[key];
      if (value == null && nullable) return;
      if (value is! String || !codes[code]!.contains(value)) {
        throw BackupValidationException('$key 不是稳定 wire code。');
      }
    }

    for (final row in snapshot.rows('accounts')) {
      check(row, 'accountType', 'accountType');
      check(row, 'accountSubtype', 'accountSubtype', nullable: true);
      check(row, 'source', 'accountSource');
    }
    for (final row in snapshot.rows('transactions')) {
      check(row, 'businessPurpose', 'businessPurpose');
      check(row, 'sourceKind', 'sourceKind');
    }
    for (final row in snapshot.rows('transaction_lines')) {
      check(row, 'role', 'transactionRole');
    }
    for (final row in snapshot.rows('entries')) {
      check(row, 'direction', 'direction');
    }
    for (final row in snapshot.rows('credit_liability_accounts')) {
      check(row, 'kind', 'creditLiabilityKind');
    }
    for (final row in snapshot.rows('bills')) {
      check(row, 'status', 'billStatus');
    }
    for (final row in snapshot.rows('bill_items')) {
      check(row, 'itemType', 'billItemType');
      check(row, 'status', 'billItemStatus');
    }
    for (final row in snapshot.rows('installment_contracts')) {
      check(row, 'sourceType', 'installmentSourceType');
      check(row, 'status', 'contractStatus');
    }
    for (final row in snapshot.rows('installment_schedules')) {
      check(row, 'status', 'scheduleStatus');
    }
    for (final row in snapshot.rows('import_entity_mappings')) {
      check(row, 'source', 'importSource');
      check(row, 'entityKind', 'importEntityKind');
    }
    for (final row in snapshot.rows('import_batches')) {
      check(row, 'source', 'importSource');
      check(row, 'status', 'importBatchStatus');
    }
    for (final row in snapshot.rows('repayments')) {
      check(row, 'repaymentType', 'repaymentType');
    }
  }

  static BackupValidationReport evaluateSnapshot(BackupSnapshot snapshot) {
    try {
      validateSnapshot(snapshot);
      return const BackupValidationReport(errors: []);
    } on BackupValidationException catch (error) {
      return BackupValidationReport(errors: [error.message]);
    } on FormatException catch (error) {
      return BackupValidationReport(errors: [error.message]);
    }
  }

  static Map<String, BackupJson> _index(Iterable<BackupJson> rows) => {
    for (final row in rows) '${row['id']}': row,
  };

  static Map<String, BackupJson> _indexByIdentity(
    Iterable<BackupJson> rows,
    String table,
  ) {
    final result = <String, BackupJson>{};
    for (final row in rows) {
      if (table == 'transaction_tags') {
        if (row['transactionId'] is! String ||
            row['transactionId'] == '' ||
            row['tagId'] is! String ||
            row['tagId'] == '') {
          throw BackupValidationException('表 $table 存在无效复合主键。');
        }
      } else if (table == 'bill_generation_suppressions') {
        if (row['accountId'] is! String ||
            row['accountId'] == '' ||
            row['period'] is! int) {
          throw BackupValidationException('表 $table 存在无效复合主键。');
        }
      } else if (row['id'] is! String || row['id'] == '') {
        throw BackupValidationException('表 $table 存在无效主键。');
      }
      final identity = table == 'transaction_tags'
          ? '${row['transactionId']}\u0000${row['tagId']}'
          : table == 'bill_generation_suppressions'
          ? '${row['accountId']}\u0000${row['period']}'
          : '${row['id']}';
      if (result.containsKey(identity)) {
        throw BackupValidationException('表 $table 存在重复主键。');
      }
      result[identity] = row;
    }
    return result;
  }

  static void _requiredReference(
    BackupJson row,
    String key,
    Map<String, BackupJson> target,
    String field,
  ) {
    final value = row[key];
    if (value is! String || value.isEmpty || !target.containsKey(value)) {
      throw BackupValidationException('$field 引用了不存在的记录。');
    }
  }

  static void _optionalReference(
    BackupJson row,
    String key,
    Map<String, BackupJson> target,
    String field,
  ) {
    final value = row[key];
    if (value != null &&
        (value is! String || value.isEmpty || !target.containsKey(value))) {
      throw BackupValidationException('$field 引用了不存在的记录。');
    }
  }

  static void _requiredIdentity(BackupJson row, String key, String field) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw BackupValidationException('$field 不是有效的历史身份。');
    }
  }

  static void _validatePostingBalance(
    BackupSnapshot snapshot,
    Map<String, BackupJson> accounts,
  ) {
    final transactions = <String, List<BackupJson>>{};
    for (final row in snapshot.rows('entries')) {
      (transactions['${row['transactionId']}'] ??= []).add(row);
    }
    final deltas = <String, int>{};
    for (final transactionId
        in snapshot.rows('transactions').map((row) => '${row['id']}')) {
      if ((transactions[transactionId]?.length ?? 0) < 2) {
        throw BackupValidationException('交易 $transactionId 的分录不足两条。');
      }
    }
    for (final entry in transactions.entries) {
      var debit = 0;
      var credit = 0;
      for (final row in entry.value) {
        final amount = _int(row['amountMinor'], 'entries.amountMinor');
        if (amount <= 0) {
          throw const BackupValidationException('分录金额必须为正数。');
        }
        switch (row['direction']) {
          case 'debit':
            debit += amount;
            break;
          case 'credit':
            credit += amount;
            break;
          default:
            throw BackupValidationException(
              'entries.direction 不是稳定 wire code。',
            );
        }
        final accountId = '${row['accountId']}';
        final accountType = accounts[accountId]?['accountType'];
        final positive = accountType == 'asset' || accountType == 'expense'
            ? row['direction'] == 'debit'
            : row['direction'] == 'credit';
        deltas[accountId] =
            (deltas[accountId] ?? 0) + (positive ? amount : -amount);
      }
      if (debit != credit) {
        throw BackupValidationException('交易 ${entry.key} 的借贷不平衡。');
      }
    }
    for (final account in accounts.entries) {
      final expected = _int(
        account.value['balanceMinor'],
        'accounts.balanceMinor',
      );
      final actual = deltas[account.key] ?? 0;
      if (expected != actual) {
        throw BackupValidationException('账户 ${account.key} 的余额与分录不一致。');
      }
    }
  }

  static int _int(Object? value, String field) {
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    throw BackupValidationException('$field 不是整数。');
  }

  static Uint8List _encodeNdjson(Iterable<BackupJson> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(jsonEncode(row));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static List<BackupJson> _decodeNdjson(Uint8List bytes, String path) {
    final text = utf8.decode(bytes, allowMalformed: false);
    if (text.isEmpty) return const [];
    final rows = <BackupJson>[];
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw BackupValidationException('$path 包含非 JSON 对象记录。');
      }
      if (decoded.keys.any((key) => key is! String)) {
        throw BackupValidationException('$path 包含非字符串 JSON 键。');
      }
      rows.add({
        for (final entry in decoded.entries) entry.key as String: entry.value,
      });
    }
    return rows;
  }
}
