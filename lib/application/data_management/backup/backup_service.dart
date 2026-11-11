import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/insurance/valobj/insurance_enums.dart';

import 'backup_models.dart';

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
      backupSchemaVersion: BackupManifest.currentBackupSchemaVersion,
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
    if (manifest.backupSchemaVersion <
            BackupManifest.minimumSupportedBackupSchemaVersion ||
        manifest.backupSchemaVersion >
            BackupManifest.currentBackupSchemaVersion) {
      throw BackupValidationException(
        '备份 backupSchemaVersion ${manifest.backupSchemaVersion} 不受支持；'
        '当前支持范围是 '
        '${BackupManifest.minimumSupportedBackupSchemaVersion}'
        '..${BackupManifest.currentBackupSchemaVersion}。',
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
    final requiredTables = manifest.backupSchemaVersion < 10
        ? <String>{
            for (final table in BackupTables.all)
              if (!BackupTables.insurance.contains(table)) table,
            ...BackupTables.insuranceV9,
          }
        : BackupTables.all;
    for (final table in requiredTables) {
      if (!tables.containsKey(table)) {
        throw BackupValidationException('备份缺少业务表文件: $table');
      }
    }
    final preferences = (tables.remove('preferences')!.single);
    final decoded = BackupSnapshot(tables: tables, preferences: preferences);
    final snapshot = _upgradeSnapshot(
      decoded,
      fromVersion: manifest.backupSchemaVersion,
    );
    validateSnapshot(snapshot);
    return BackupInspection(manifest: manifest, snapshot: snapshot);
  }

  static BackupSnapshot _upgradeSnapshot(
    BackupSnapshot snapshot, {
    required int fromVersion,
  }) {
    var upgraded = snapshot;
    for (
      var version = fromVersion;
      version < BackupManifest.currentBackupSchemaVersion;
      version++
    ) {
      upgraded = switch (version) {
        9 => _upgradeBackupV9ToV10(upgraded),
        _ => throw BackupValidationException(
          '备份 backupSchemaVersion $version 到当前 '
          '${BackupManifest.currentBackupSchemaVersion} 的迁移尚未实现。',
        ),
      };
    }
    return upgraded;
  }

  static BackupSnapshot _upgradeBackupV9ToV10(BackupSnapshot snapshot) {
    final tables = {...snapshot.tables};
    tables['commercial_insurances'] = [
      for (final row in snapshot.rows('commercial_insurances'))
        Map<String, Object?>.from(row)
          ..putIfAbsent('premiumTermCount', () => null)
          ..remove('coverageAmountNote')
          ..remove('premiumNote')
          ..update(
            'premiumFrequency',
            (value) => value == 'quarterly' || value == 'semiAnnual'
                ? PremiumFrequency.other.name
                : value,
            ifAbsent: () => null,
          ),
    ];
    tables['coverage_responsibilities'] = [
      for (final row in snapshot.rows('coverage_responsibilities'))
        Map<String, Object?>.from(row)..update(
          'kind',
          (value) => value == 'custom' ? ResponsibilityKind.other.name : value,
        ),
    ];
    if (snapshot.rows('social_insurances').isEmpty &&
        snapshot.rows('social_contribution_records').isEmpty) {
      tables['social_insurances'] = [
        for (final row in snapshot.rows('social_medical_insurances'))
          _socialInsuranceRowFromLegacy(row, SocialInsuranceType.medical),
        for (final row in snapshot.rows('social_pension_insurances'))
          _socialInsuranceRowFromLegacy(row, SocialInsuranceType.pension),
      ];
      tables['social_contribution_records'] = [
        for (final row in snapshot.rows('social_medical_contribution_records'))
          _socialContributionRowFromLegacy(
            row,
            legacyIdKey: 'socialMedicalInsuranceId',
          ),
        for (final row in snapshot.rows('social_pension_contribution_records'))
          _socialContributionRowFromLegacy(
            row,
            legacyIdKey: 'socialPensionInsuranceId',
          ),
      ];
    }
    for (final table in BackupTables.insuranceV9.where(
      (table) => table.startsWith('social_'),
    )) {
      tables.remove(table);
    }
    return snapshot.copyWith(tables: tables);
  }

  static BackupJson _socialInsuranceRowFromLegacy(
    BackupJson row,
    SocialInsuranceType type,
  ) {
    return Map<String, Object?>.from(row)..['insuranceType'] = type.name;
  }

  static BackupJson _socialContributionRowFromLegacy(
    BackupJson row, {
    required String legacyIdKey,
  }) {
    return Map<String, Object?>.from(row)
      ..['socialInsuranceId'] = row[legacyIdKey]
      ..remove(legacyIdKey);
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
    final advanceCases = _index(snapshot.rows('advance_cases'));
    final amortizationPlans = _index(snapshot.rows('amortization_plans'));
    final amortizationPeriods = _index(snapshot.rows('amortization_periods'));
    final amortizationRefunds = _index(snapshot.rows('amortization_refunds'));
    final amortizationTerminations = _index(
      snapshot.rows('amortization_terminations'),
    );
    final tags = _index(snapshot.rows('tags'));
    final counterparties = _index(snapshot.rows('counterparties'));
    final contracts = _index(snapshot.rows('installment_contracts'));
    final products = _index(snapshot.rows('installment_products'));
    final stages = _index(snapshot.rows('installment_stage_configs'));
    _validateInstallmentStages(snapshot, contracts, products, stages);
    _validateInsurance(snapshot);
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
      _optionalReference(
        row,
        'counterpartyId',
        counterparties,
        'transactions.counterpartyId',
      );
      final ownerType = row['ownerType'];
      final ownerId = row['ownerId'];
      if ((ownerType == null) != (ownerId == null)) {
        throw const BackupValidationException('交易业务归属必须同时为空或同时存在。');
      }
      if (ownerType is String &&
          (ownerType.trim().isEmpty ||
              ownerId is! String ||
              ownerId.trim().isEmpty)) {
        throw const BackupValidationException('交易业务归属包含空标识。');
      }
      if (ownerType == 'orchestration.advance') {
        _requiredReference(
          row,
          'ownerId',
          advanceCases,
          'transactions.ownerId',
        );
      }
      if (ownerType == 'orchestration.amortization') {
        _requiredReference(
          row,
          'ownerId',
          amortizationPlans,
          'transactions.ownerId',
        );
      }
      if (ownerType == 'credit.installment_contract') {
        _requiredReference(row, 'ownerId', contracts, 'transactions.ownerId');
      }
      if (ownerType == 'credit.repayment') {
        _requiredReference(row, 'ownerId', repayments, 'transactions.ownerId');
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
    final counterpartyNames = <String>{};
    for (final row in snapshot.rows('counterparties')) {
      _requiredText(row, 'name', 'counterparties.name');
      if (!counterpartyNames.add('${row['name']}')) {
        throw const BackupValidationException('对手方名称重复。');
      }
    }
    for (final row in snapshot.rows('budgets')) {
      _optionalText(row, 'accountId', 'budgets.accountId');
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
    final contractSources = <String>{};
    for (final row in snapshot.rows('installment_contracts')) {
      _requiredReference(
        row,
        'liabilityAccountId',
        accounts,
        'installment_contracts.liabilityAccountId',
      );
      final installmentType = row['installmentType'];
      final sourceRefId = row['sourceRefId'];
      switch (installmentType) {
        case 'disbursement':
          _optionalReference(
            row,
            'sourceRefId',
            transactions,
            'installment_contracts.sourceRefId',
          );
          break;
        case 'billConversion':
          _requiredReference(
            row,
            'sourceRefId',
            repayments,
            'installment_contracts.sourceRefId',
          );
          final repayment = repayments[sourceRefId];
          if (repayment?['generatedContractId'] != row['id']) {
            throw const BackupValidationException('账单分期来源还款未回指对应合同。');
          }
          break;
        case 'purchase':
          _requiredReference(
            row,
            'sourceRefId',
            transactions,
            'installment_contracts.sourceRefId',
          );
          break;
        default:
          throw const BackupValidationException(
            'installment_contracts.installmentType 不是稳定 wire code。',
          );
      }
      if (sourceRefId != null &&
          !contractSources.add('$installmentType\u0000$sourceRefId')) {
        throw const BackupValidationException('一项来源事实关联了多份分期合同。');
      }
      if (installmentType != 'billConversion' && sourceRefId is String) {
        final transaction = transactions[sourceRefId];
        if (transaction?['ownerType'] != 'credit.installment_contract' ||
            transaction?['ownerId'] != row['id']) {
          throw const BackupValidationException('分期来源交易未回指对应合同。');
        }
      }
    }
    for (final row in snapshot.rows('installment_schedules')) {
      _requiredReference(
        row,
        'contractId',
        contracts,
        'installment_schedules.contractId',
      );
    }
    final generatedContractIds = <String>{};
    for (final row in snapshot.rows('repayments')) {
      _optionalReference(
        row,
        'transactionId',
        transactions,
        'repayments.transactionId',
      );
      _optionalReference(
        row,
        'generatedContractId',
        contracts,
        'repayments.generatedContractId',
      );
      final generatedContractId = row['generatedContractId'];
      if (row['repaymentType'] == 'INSTALLMENT') {
        if (generatedContractId is! String) {
          throw const BackupValidationException('账单分期还款缺少生成合同引用。');
        }
        if (!generatedContractIds.add(generatedContractId)) {
          throw const BackupValidationException('同一合同被多笔账单分期还款生成。');
        }
        final contract = contracts[generatedContractId];
        if (contract?['installmentType'] != 'billConversion' ||
            contract?['sourceRefId'] != row['id']) {
          throw const BackupValidationException('账单分期还款与合同来源关系无效。');
        }
      } else if (generatedContractId != null) {
        throw const BackupValidationException('非账单分期还款不能生成合同。');
      }
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
    for (final row in snapshot.rows('installment_refund_reductions')) {
      _requiredReference(
        row,
        'contractId',
        contracts,
        'installment_refund_reductions.contractId',
      );
      _requiredReference(
        row,
        'refundTransactionId',
        transactions,
        'installment_refund_reductions.refundTransactionId',
      );
      final contract = contracts[row['contractId']];
      final transaction = transactions[row['refundTransactionId']];
      if (contract?['installmentType'] != 'purchase' ||
          transaction?['businessPurpose'] != 'refund' ||
          transaction?['ownerType'] != 'credit.installment_contract' ||
          transaction?['ownerId'] != contract?['id']) {
        throw const BackupValidationException('退款还本引用关系无效。');
      }
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
      // Default mappings are soft references. A deleted target is ignored by
      // the import review flow and can be remapped later.
      _requiredText(
        row,
        'targetAccountId',
        'import_entity_mappings.targetAccountId',
      );
    }

    final amortizationAllocationTotals = <String, int>{};
    final amortizationAllocationKeys = <String>{};
    final amortizationAllocationAccounts = <String>{};
    for (final row in snapshot.rows('amortization_allocations')) {
      final subjectType = row['subjectType'];
      final subjectId = row['subjectId'];
      final dimension = row['dimension'];
      final exists = switch (subjectType) {
        'plan' => amortizationPlans.containsKey(subjectId),
        'period' => amortizationPeriods.containsKey(subjectId),
        'refund' => amortizationRefunds.containsKey(subjectId),
        'termination' => amortizationTerminations.containsKey(subjectId),
        _ => false,
      };
      if (!exists ||
          !const {'funding', 'category', 'settlement'}.contains(dimension)) {
        throw const BackupValidationException('摊销分项归属或维度无效。');
      }
      final lineNo = row['lineNo'];
      final key = '$subjectType\u0000$subjectId\u0000$dimension';
      if (lineNo is! int ||
          lineNo <= 0 ||
          !amortizationAllocationKeys.add('$key\u0000$lineNo')) {
        throw const BackupValidationException('摊销分项顺序无效或重复。');
      }
      _requiredReference(
        row,
        'accountId',
        accounts,
        'amortization_allocations.accountId',
      );
      final accountId = row['accountId'] as String;
      if (!amortizationAllocationAccounts.add('$key\u0000$accountId')) {
        throw const BackupValidationException('摊销分项账户重复。');
      }
      final amount = _int(
        row['amountMinor'],
        'amortization_allocations.amountMinor',
      );
      if (amount <= 0) {
        throw const BackupValidationException('摊销分项金额必须为正数。');
      }
      amortizationAllocationTotals[key] =
          (amortizationAllocationTotals[key] ?? 0) + amount;
    }

    for (final row in amortizationPlans.values) {
      final planId = '${row['id']}';
      _requiredReference(
        row,
        'deferralAccountId',
        accounts,
        'amortization_plans.deferralAccountId',
      );
      _requiredReference(
        row,
        'initialTransactionId',
        transactions,
        'amortization_plans.initialTransactionId',
      );
      final initial = transactions['${row['initialTransactionId']}'];
      if (initial?['ownerType'] != 'orchestration.amortization' ||
          initial?['ownerId'] != planId) {
        throw const BackupValidationException('摊销初始交易未回指对应计划。');
      }
      final total = _int(
        row['totalAmountMinor'],
        'amortization_plans.totalAmountMinor',
      );
      if (amortizationAllocationTotals['plan\u0000$planId\u0000funding'] !=
              total ||
          amortizationAllocationTotals['plan\u0000$planId\u0000category'] !=
              total) {
        throw const BackupValidationException('摊销计划分项必须等于原始金额。');
      }
    }

    final periodSequences = <String>{};
    final generatedTransactions = <String>{};
    for (final row in amortizationPeriods.values) {
      final periodId = '${row['id']}';
      final planId = row['planId'];
      if (planId is! String || !amortizationPlans.containsKey(planId)) {
        throw const BackupValidationException('摊销期次引用了不存在的计划。');
      }
      final sequenceNo = row['sequenceNo'];
      if (sequenceNo is! int ||
          sequenceNo <= 0 ||
          !periodSequences.add('$planId\u0000$sequenceNo')) {
        throw const BackupValidationException('摊销期次序号无效或重复。');
      }
      final amount = _int(
        row['amountMinor'],
        'amortization_periods.amountMinor',
      );
      if (amount < 0) {
        throw const BackupValidationException('摊销期次金额不能为负数。');
      }
      final status = row['status'];
      if (!const {'pending', 'posted', 'zero', 'canceled'}.contains(status)) {
        throw const BackupValidationException('摊销期次状态无效。');
      }
      final transactionId = row['transactionId'];
      if (status == 'posted') {
        if (transactionId is! String ||
            !transactions.containsKey(transactionId) ||
            !generatedTransactions.add(transactionId)) {
          throw const BackupValidationException('摊销期次确认交易无效或重复。');
        }
        final transaction = transactions[transactionId];
        if (transaction?['ownerType'] != 'orchestration.amortization' ||
            transaction?['ownerId'] != planId) {
          throw const BackupValidationException('摊销期次交易归属无效。');
        }
      } else if (transactionId != null) {
        throw const BackupValidationException('非已确认期次不能引用交易。');
      }
      final categoryTotal =
          amortizationAllocationTotals['period\u0000$periodId\u0000category'] ??
          0;
      if (categoryTotal != amount) {
        throw const BackupValidationException('摊销期次分类分配合计必须等于期次金额。');
      }
    }

    for (final row in amortizationRefunds.values) {
      final refundId = '${row['id']}';
      final planId = row['planId'];
      if (planId is! String || !amortizationPlans.containsKey(planId)) {
        throw const BackupValidationException('摊销退款引用了不存在的计划。');
      }
      _requiredReference(
        row,
        'transferTransactionId',
        transactions,
        'amortization_refunds.transferTransactionId',
      );
      final transfer = transactions['${row['transferTransactionId']}'];
      if (transfer?['ownerType'] != 'orchestration.amortization' ||
          transfer?['ownerId'] != planId) {
        throw const BackupValidationException('摊销退款交易归属无效。');
      }
      final categoryTotal =
          amortizationAllocationTotals['refund\u0000$refundId\u0000category'] ??
          0;
      final settlementTotal =
          amortizationAllocationTotals['refund\u0000$refundId\u0000settlement'] ??
          0;
      if (categoryTotal <= 0 || categoryTotal != settlementTotal) {
        throw const BackupValidationException('摊销退款分配合计无效。');
      }
    }

    for (final row in amortizationTerminations.values) {
      final terminationId = '${row['id']}';
      final planId = row['planId'];
      if (planId is! String || !amortizationPlans.containsKey(planId)) {
        throw const BackupValidationException('摊销终止引用了不存在的计划。');
      }
      for (final field in const [
        'recognitionTransactionId',
        'returnTransactionId',
      ]) {
        _optionalReference(
          row,
          field,
          transactions,
          'amortization_terminations.$field',
        );
      }
      final categoryTotal =
          amortizationAllocationTotals['termination\u0000$terminationId\u0000category'] ??
          0;
      final settlementTotal =
          amortizationAllocationTotals['termination\u0000$terminationId\u0000settlement'] ??
          0;
      if (categoryTotal != settlementTotal) {
        throw const BackupValidationException('摊销终止分配合计无效。');
      }
    }

    _validatePostingBalance(snapshot, accounts);
  }

  static bool _isUtcCalendarDate(Object? value) =>
      value is int &&
      value >= -8640000000000000 &&
      value <= 8640000000000000 &&
      value % Duration.millisecondsPerDay == 0;

  static bool _isRepricingStage(
    BackupJson row,
    Map<String, BackupJson> stages,
  ) {
    final stage = stages[row['stageId']];
    return stage != null &&
        stage['contractId'] == row['contractId'] &&
        stage['stageKind'] == 'repayment';
  }

  static bool _isValidRepricingRate(
    BackupJson row,
    Set<String> referenceRateKeys,
  ) => switch (row['pricingMethod']) {
    'direct' =>
      row['ratePpm'] is int &&
          (row['ratePpm'] as int) >= 0 &&
          InterestRatePeriod.values.any(
            (period) => period.name == row['ratePeriod'],
          ) &&
          const [
            'resetDate',
            'referenceRateDate',
            'referenceRateType',
            'referenceRatePpm',
            'spreadBp',
            'source',
          ].every((field) => row[field] == null),
    'reference' =>
      row['ratePpm'] == null &&
          row['ratePeriod'] == null &&
          referenceRateKeys.contains(
            '${row['referenceRateDate']}:${row['referenceRateType']}',
          ) &&
          _isUtcCalendarDate(row['resetDate']) &&
          _isUtcCalendarDate(row['referenceRateDate']) &&
          (row['referenceRateDate'] as int) <= (row['resetDate'] as int) &&
          (row['resetDate'] as int) <= (row['effectiveDate'] as int) &&
          row['referenceRatePpm'] is int &&
          row['spreadBp'] is int &&
          row['source'] is String &&
          (row['referenceRatePpm'] as int) >= 0 &&
          (row['referenceRatePpm'] as int) + (row['spreadBp'] as int) * 100 >=
              0,
    _ => false,
  };

  static void _validateInstallmentOperations(
    BackupSnapshot snapshot,
    Map<String, BackupJson> contracts,
    Map<String, BackupJson> stages,
  ) {
    final configurationDates = <String>{};
    for (final row in snapshot.rows('installment_repricing_configs')) {
      _requiredReference(
        row,
        'contractId',
        contracts,
        'installment_repricing_configs.contractId',
      );
      if (!_isRepricingStage(row, stages) ||
          !_isUtcCalendarDate(row['effectiveFrom']) ||
          !_isUtcCalendarDate(row['firstResetDate']) ||
          !_isUtcCalendarDate(row['firstEffectiveDate']) ||
          (row['firstResetDate'] as int) > (row['firstEffectiveDate'] as int) ||
          row['spreadBp'] is! int ||
          row['generationCompleted'] is! bool ||
          !const {3, 6, 12}.contains(row['cycleMonths']) ||
          (row['lastGeneratedDate'] != null &&
              (!_isUtcCalendarDate(row['lastGeneratedDate']) ||
                  (row['lastGeneratedDate'] as int) <
                      (row['effectiveFrom'] as int))) ||
          !InterestRateType.referenceTypes.any(
            (type) => type.name == row['referenceRateType'],
          ) ||
          !configurationDates.add(
            '${row['contractId']}:${row['stageId']}:${row['effectiveFrom']}',
          )) {
        throw const BackupValidationException('阶段重定价配置无效或生效日重复');
      }
    }
    final adjustments = <String, List<BackupJson>>{};
    for (final row in snapshot.rows('installment_interest_adjustments')) {
      _requiredReference(
        row,
        'contractId',
        contracts,
        'installment_interest_adjustments.contractId',
      );
      if (!_isUtcCalendarDate(row['startDate']) ||
          !_isUtcCalendarDate(row['endDate']) ||
          row['ratioPpm'] is! int ||
          (row['startDate'] as int) >= (row['endDate'] as int) ||
          (row['ratioPpm'] as int) < 0) {
        throw const BackupValidationException('合同利息调整区间或比例无效');
      }
      adjustments.putIfAbsent(row['contractId'] as String, () => []).add(row);
    }
    for (final values in adjustments.values) {
      values.sort(
        (a, b) => (a['startDate'] as int).compareTo(b['startDate'] as int),
      );
      for (var i = 1; i < values.length; i++) {
        if ((values[i]['startDate'] as int) <
            (values[i - 1]['endDate'] as int)) {
          throw const BackupValidationException('同一合同的利息调整区间不能重叠');
        }
      }
    }
  }

  static void _validateInstallmentStages(
    BackupSnapshot snapshot,
    Map<String, BackupJson> contracts,
    Map<String, BackupJson> products,
    Map<String, BackupJson> stages,
  ) {
    const variableFields = [
      'periods',
      'initialRatePpm',
      'endPrincipalMinor',
      'fixedAmountMinor',
      'feeMinor',
      'endDate',
      'firstDate',
      'accrualStartDate',
      'referenceRateType',
      'spreadBp',
      'firstResetDate',
      'firstEffectiveDate',
    ];
    final productStages = _index(
      snapshot.rows('installment_product_stage_configs'),
    );
    final allStages = [
      for (final row in stages.values) (row, 'contract', row['contractId']),
      for (final row in productStages.values)
        (row, 'product', row['productId']),
    ];
    _validateInstallmentOperations(snapshot, contracts, stages);
    final stagesByOwner = <String, List<BackupJson>>{};
    for (final (stage, owner, ownerId) in allStages) {
      stagesByOwner.putIfAbsent('$owner:$ownerId', () => []).add(stage);
    }
    for (final values in stagesByOwner.values) {
      if (values.any((row) => row['repaymentMethod'] == 'custom') &&
          values.any((row) => row['repaymentMethod'] != 'custom')) {
        throw const BackupValidationException('自定义阶段不能与其他阶段混用');
      }
    }
    final positions = <String>{};
    final resetKeys = <String>{};
    final referenceRateKeys = {
      for (final rate in snapshot.rows('reference_rates'))
        '${rate['rateDate']}:${rate['type']}',
    };
    for (final row in snapshot.rows('installment_repricing_records')) {
      if (!const {
            'pending',
            'applied',
            'userConfirmed',
          }.contains(row['status']) ||
          !contracts.containsKey(row['contractId']) ||
          !_isRepricingStage(row, stages) ||
          !_isUtcCalendarDate(row['effectiveDate']) ||
          !_isValidRepricingRate(row, referenceRateKeys) ||
          !resetKeys.add(
            '${row['contractId']}:${row['stageId']}:${row['effectiveDate']}',
          )) {
        throw const BackupValidationException('重定价结果的合同、阶段或生效日期无效');
      }
    }
    if (stages.length != snapshot.rows('installment_stage_configs').length ||
        productStages.length !=
            snapshot.rows('installment_product_stage_configs').length ||
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
          }.contains(row['rounding'])) {
        throw const BackupValidationException('分期计算约定无效');
      }
    }
    for (final (row, owner, ownerId) in allStages) {
      if (owner == 'contract' &&
          const [
            'rateType',
            'referenceRateType',
            'spreadBp',
            'firstResetDate',
            'firstEffectiveDate',
            'repricingCycleMonths',
          ].any((field) => row[field] != null)) {
        throw const BackupValidationException('重定价配置必须归属合同配置历史');
      }
      if (row['inPeriodRepricingPolicy'] != null &&
          !const {
            'preservePrincipal',
            'dynamicPeriodRate',
          }.contains(row['inPeriodRepricingPolicy'])) {
        throw const BackupValidationException('期中重定价还款策略无效');
      }
      if (owner != 'product' && owner != 'contract') {
        throw const BackupValidationException('阶段归属类型无效');
      }
      _requiredReference(
        row,
        owner == 'product' ? 'productId' : 'contractId',
        owner == 'product' ? products : contracts,
        '阶段所属产品或合同',
      );
      final position = row['position'];
      if (position is! int ||
          position < 0 ||
          !positions.add('$owner:$ownerId:$position')) {
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
              'rateType',
              'tailDifference',
              'repricingCycleMonths',
              'inPeriodRepricingPolicy',
              ...variableFields.where((f) => f != 'endDate'),
            ].any((f) => row[f] != null) ||
            (owner == 'contract' && row['endDate'] is! int)) {
          throw const BackupValidationException('免还阶段配置无效');
        }
      } else {
        if (row['tailDifference'] != 'lastPeriod') {
          throw const BackupValidationException('阶段尾差处理策略无效');
        }
        if (owner == 'product') {
          final hasInterest =
              row['repaymentMethod'] != 'flatFee' &&
              row['repaymentMethod'] != 'custom';
          if (hasInterest &&
                  !InterestRateType.values.any(
                    (t) => t.name == row['rateType'],
                  ) ||
              !hasInterest && row['rateType'] != null) {
            throw const BackupValidationException('产品阶段利率类型无效');
          }
          if (hasInterest &&
              row['rateType'] != 'fixed' &&
              (row['ratePeriod'] != 'annual' ||
                  !const {3, 6, 12}.contains(row['repricingCycleMonths']) ||
                  row['amountAlgorithm'] == 'fixed')) {
            throw const BackupValidationException('产品阶段重定价规则无效');
          }
          if ((!hasInterest || row['rateType'] == 'fixed') &&
              row['repricingCycleMonths'] != null) {
            throw const BackupValidationException('固定利率阶段不使用重定价周期');
          }
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
            (row['firstDate'] is! int ||
                row['endDate'] is! int ||
                row['periods'] is! int ||
                (row['endDate'] as int) < (row['firstDate'] as int))) {
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
                row['inPeriodRepricingPolicy'] != null ||
                row['fixedAmountMinor'] != null)) {
          throw const BackupValidationException('非等额本息阶段不能指定固定额算法');
        }
        for (final field in [
          'periods',
          'intervalMonths',
          'fixedAmountMinor',
          'initialRatePpm',
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
        if (owner == 'contract' &&
            ((row['initialRatePpm'] == null) != (row['ratePeriod'] == null))) {
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
        final owned = [...?stagesByOwner['${entry.key}:$id']]
          ..sort(
            (a, b) => (a['position'] as int).compareTo(b['position'] as int),
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
          (stage['contractId'] != row['contractId'] ||
              stage['stageKind'] != 'repayment')) {
        throw const BackupValidationException('计划期次与所属合同阶段不一致');
      }
    }
  }

  static void _validateWireCodes(BackupSnapshot snapshot) {
    final codes = <String, Set<String>>{
      'accountType': {'asset', 'liability', 'equity', 'income', 'expense'},
      'accountSubtype': {
        'fund',
        'receivable',
        'prepaidExpense',
        'payable',
        'loan',
        'deferredIncome',
      },
      'accountSource': {'builtin', 'user', 'import'},
      'businessPurpose': {
        'dailyExpense',
        'dailyIncome',
        'transfer',
        'refund',
        'advance',
        'advanceCollection',
        'advanceSettlement',
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
        'advanceExpenseCategory',
        'advanceSelfBorne',
        'advanceCompensationIncome',
        'advanceBadDebtExpense',
        'openingBalance',
        'balanceAdjustment',
      },
      'direction': {'debit', 'credit'},
      'creditLiabilityKind': {'credit', 'loan'},
      'billStatus': {'open', 'billed', 'settled'},
      'billItemType': {'consumption', 'installment'},
      'billItemStatus': {'pending', 'partiallyPaid', 'paid', 'skipped'},
      'installmentType': {'disbursement', 'billConversion', 'purchase'},
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
      'advanceScenario': {'aa', 'onBehalf', 'reimbursement'},
      'advanceTrackingMode': {'itemized', 'account'},
      'amortizationKind': {'prepaidExpense', 'deferredIncome'},
      'amortizationCadenceUnit': {'daily', 'monthly', 'yearly'},
      'commercialInsuranceCategory': {
        for (final value in CommercialInsuranceCategory.values) value.name,
      },
      'premiumFrequency': {
        for (final value in PremiumFrequency.values) value.name,
      },
      'responsibilityKind': {
        for (final value in ResponsibilityKind.values) value.name,
      },
      'socialInsuranceType': {
        for (final value in SocialInsuranceType.values) value.name,
      },
      'socialParticipantType': {
        for (final value in SocialParticipantType.values) value.name,
      },
      'memberRelationship': {
        for (final value in MemberRelationship.values) value.name,
      },
      'memberGender': {for (final value in MemberGender.values) value.name},
      'memberAvatarPreset': {
        for (final value in MemberAvatarPreset.values) value.name,
      },
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
    for (final row in snapshot.rows('advance_cases')) {
      check(row, 'scenario', 'advanceScenario');
      check(row, 'trackingMode', 'advanceTrackingMode');
      final accountId = row['receivableAccountId'];
      if (row['trackingMode'] == 'account' &&
          (accountId is! String || accountId.trim().isEmpty)) {
        throw const BackupValidationException('账户垫付编排实例缺少应收账户。');
      }
      final aaPeopleCount = row['aaPeopleCount'];
      if (row['scenario'] == 'aa' &&
          (aaPeopleCount is! int || aaPeopleCount < 2 || aaPeopleCount > 99)) {
        throw const BackupValidationException('AA 参与人数无效。');
      }
      if (row['scenario'] != 'aa' && aaPeopleCount != null) {
        throw const BackupValidationException('非 AA 场景不能保存参与人数。');
      }
    }
    for (final row in snapshot.rows('amortization_plans')) {
      check(row, 'kind', 'amortizationKind');
      check(row, 'cadenceUnit', 'amortizationCadenceUnit');
      final total = row['totalAmountMinor'];
      final count = row['recognitionCount'];
      final interval = row['cadenceInterval'];
      if (total is! int ||
          total <= 0 ||
          count is! int ||
          count <= 0 ||
          count > total ||
          interval is! int ||
          interval <= 0) {
        throw const BackupValidationException('摊销计划金额或期次配置无效。');
      }
      final terminatedAt = row['terminatedAt'];
      if (terminatedAt == null &&
          (row['refundAmountMinor'] != null ||
              row['terminationRecognitionTransactionId'] != null ||
              row['refundTransactionId'] != null)) {
        throw const BackupValidationException('未终止摊销计划包含终止事实。');
      }
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
      check(row, 'installmentType', 'installmentType');
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
    for (final row in snapshot.rows('commercial_insurances')) {
      check(row, 'category', 'commercialInsuranceCategory');
      check(row, 'premiumFrequency', 'premiumFrequency', nullable: true);
      final termCount = row['premiumTermCount'];
      if (termCount != null && (termCount is! int || termCount <= 0)) {
        throw const BackupValidationException('缴费期数必须为正整数。');
      }
    }
    for (final row in snapshot.rows('coverage_responsibilities')) {
      check(row, 'kind', 'responsibilityKind');
    }
    for (final row in snapshot.rows('insured_people')) {
      check(row, 'relationship', 'memberRelationship');
      check(row, 'gender', 'memberGender');
      check(row, 'avatarPreset', 'memberAvatarPreset');
      final note = row['note'];
      if (note != null && (note is! String || note.length > 100)) {
        throw const BackupValidationException('成员备注格式无效。');
      }
    }
    for (final row in snapshot.rows('social_insurances')) {
      check(row, 'insuranceType', 'socialInsuranceType');
      check(row, 'participantType', 'socialParticipantType');
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
      } else if (table == 'reference_rates') {
        if (row['rateDate'] is! int ||
            !InterestRateType.referenceTypes.any(
              (t) => t.name == row['type'],
            ) ||
            row['ratePpm'] is! int ||
            (row['ratePpm'] as int) < 0 ||
            row['source'] is! String ||
            row['source'] == '') {
          throw const BackupValidationException('参考利率日期、类型或数值无效');
        }
      } else if (table == 'commercial_insurance_insured_people') {
        if (row['commercialInsuranceId'] is! String ||
            (row['commercialInsuranceId'] as String).isEmpty ||
            row['insuredPersonId'] is! String ||
            (row['insuredPersonId'] as String).isEmpty) {
          throw BackupValidationException('表 $table 存在无效复合主键。');
        }
      } else if (table == 'social_contribution_records') {
        final insuranceId = row['socialInsuranceId'];
        if (insuranceId is! String ||
            insuranceId.isEmpty ||
            row['yearMonth'] is! String ||
            (row['yearMonth'] as String).isEmpty) {
          throw BackupValidationException('表 $table 存在无效复合主键。');
        }
      } else if (row['id'] is! String || row['id'] == '') {
        throw BackupValidationException('表 $table 存在无效主键。');
      }
      final identity = table == 'transaction_tags'
          ? '${row['transactionId']}\u0000${row['tagId']}'
          : table == 'bill_generation_suppressions'
          ? '${row['accountId']}\u0000${row['period']}'
          : table == 'reference_rates'
          ? '${row['rateDate']}\u0000${row['type']}'
          : table == 'commercial_insurance_insured_people'
          ? '${row['commercialInsuranceId']}\u0000${row['insuredPersonId']}'
          : table == 'social_contribution_records'
          ? '${row['socialInsuranceId']}\u0000${row['yearMonth']}'
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

  static void _requiredText(BackupJson row, String key, String field) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw BackupValidationException('$field 不是有效的文本。');
    }
  }

  static void _optionalText(BackupJson row, String key, String field) {
    final value = row[key];
    if (value != null && (value is! String || value.trim().isEmpty)) {
      throw BackupValidationException('$field 不是有效的文本。');
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

  static void _validateInsurance(BackupSnapshot snapshot) {
    final people = _index(snapshot.rows('insured_people'));
    final commercial = _index(snapshot.rows('commercial_insurances'));
    final responsibilities = _index(snapshot.rows('coverage_responsibilities'));
    final social = _index(snapshot.rows('social_insurances'));

    for (final row in snapshot.rows('insured_people')) {
      _requiredText(row, 'name', '被保险人姓名');
      final birthDate = _backupDate(
        row['birthDate'],
        'insured_people.birthDate',
      );
      if (birthDate.year < 1900 || birthDate.year > 2100) {
        throw const BackupValidationException('被保险人出生日期无效。');
      }
    }

    final linkedPeopleByInsurance = <String, Set<String>>{};
    for (final row in snapshot.rows('commercial_insurance_insured_people')) {
      _requiredReference(
        row,
        'commercialInsuranceId',
        commercial,
        '商业保险被保险人关联.commercialInsuranceId',
      );
      _requiredReference(
        row,
        'insuredPersonId',
        people,
        '商业保险被保险人关联.insuredPersonId',
      );
      (linkedPeopleByInsurance['${row['commercialInsuranceId']}'] ??=
              <String>{})
          .add('${row['insuredPersonId']}');
    }

    for (final row in snapshot.rows('commercial_insurances')) {
      _requiredText(row, 'name', '商业保险名称');
      _requiredText(row, 'insurerName', '保险公司');
      final start = _backupDate(row['coverageStartDate'], '保障开始日');
      final endValue = row['coverageEndDate'];
      final end = endValue == null ? null : _backupDate(endValue, '保障结束日');
      final lifetime = row['lifetime'];
      if (lifetime is! bool) {
        throw const BackupValidationException('终身保障标记无效。');
      }
      if (lifetime && end != null) {
        throw const BackupValidationException('终身保障不能填写结束日期。');
      }
      if (end != null && end.isBefore(start)) {
        throw const BackupValidationException('保障结束日不能早于开始日。');
      }
      for (final key in const ['coverageAmountMinor', 'premiumAmountMinor']) {
        final amount = row[key];
        if (amount != null && _int(amount, 'commercial_insurances.$key') < 0) {
          throw const BackupValidationException('保险金额不能为负数。');
        }
      }
      final insuredPeople = linkedPeopleByInsurance['${row['id']}'];
      if (insuredPeople == null || insuredPeople.isEmpty) {
        throw const BackupValidationException('商业保险至少关联一个被保险人。');
      }
    }

    final pointsByResponsibility = <String, List<BackupJson>>{};
    for (final row in snapshot.rows('responsibility_points')) {
      _requiredReference(
        row,
        'responsibilityId',
        responsibilities,
        '责任要点.responsibilityId',
      );
      _requiredText(row, 'label', '责任要点名称');
      _requiredText(row, 'value', '责任要点内容');
      if (_int(row['sortOrder'], 'responsibility_points.sortOrder') < 0) {
        throw const BackupValidationException('责任要点排序不能为负数。');
      }
      (pointsByResponsibility['${row['responsibilityId']}'] ??= []).add(row);
    }
    for (final row in snapshot.rows('coverage_responsibilities')) {
      _requiredReference(
        row,
        'commercialInsuranceId',
        commercial,
        '保障责任.commercialInsuranceId',
      );
      _requiredText(row, 'name', '保障责任名称');
      if (_int(row['sortOrder'], 'coverage_responsibilities.sortOrder') < 0) {
        throw const BackupValidationException('保障责任排序不能为负数。');
      }
      final kind = ResponsibilityKind.values
          .where((value) => value.name == row['kind'])
          .firstOrNull;
      if (kind == null) {
        throw const BackupValidationException('保障责任类型无效。');
      }
      final labels = <String>{};
      for (final point in pointsByResponsibility['${row['id']}'] ?? const []) {
        if (!labels.add('${point['label']}'.trim())) {
          throw const BackupValidationException('同一保障责任内的要点名称重复。');
        }
      }
    }

    for (final row in snapshot.rows('insurance_attachments')) {
      _requiredReference(
        row,
        'commercialInsuranceId',
        commercial,
        '保险附件.commercialInsuranceId',
      );
      _requiredText(row, 'fileName', '附件文件名');
      _requiredText(row, 'storageKey', '附件存储键');
      _requiredText(row, 'mimeType', '附件类型');
    }

    for (final row in snapshot.rows('social_insurances')) {
      _requiredReference(
        row,
        'insuredPersonId',
        people,
        'social_insurances.insuredPersonId',
      );
      _requiredText(row, 'region', '参保地区');
    }
    for (final row in snapshot.rows('social_contribution_records')) {
      final insuranceId = row['socialInsuranceId'];
      if (insuranceId is! String || !social.containsKey(insuranceId)) {
        throw const BackupValidationException(
          'social_contribution_records 引用了不存在的社保记录。',
        );
      }
      final month = row['yearMonth'];
      final match = month is String
          ? RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(month)
          : null;
      final year = match == null ? null : int.tryParse(match.group(1)!);
      if (year == null || year < 1900 || year > 2100) {
        throw const BackupValidationException('社保缴费年月无效。');
      }
      if (_int(
            row['contributionBaseMinor'],
            'social_contribution_records.contributionBaseMinor',
          ) <
          0) {
        throw const BackupValidationException('社保缴费基数不能为负数。');
      }
    }
  }

  static DateTime _backupDate(Object? value, String field) {
    final parsed = switch (value) {
      String() => DateTime.tryParse(value),
      int() => DateTime.fromMillisecondsSinceEpoch(value),
      num() when value == value.roundToDouble() =>
        DateTime.fromMillisecondsSinceEpoch(value.toInt()),
      _ => null,
    };
    if (parsed == null) {
      throw BackupValidationException('$field 不是有效日期。');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
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
