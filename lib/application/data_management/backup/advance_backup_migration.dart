import 'backup_models.dart';

/// Migrates pre-v49 backups to orchestration-owned advances and the owner
/// reference contract without `owner_role`.
void migrateAdvanceBackup(Map<String, Iterable<BackupJson>> tables) {
  final sourceTransactions = tables['transactions'] ?? const <BackupJson>[];
  final advanceParentIds = <String>{
    for (final row in sourceTransactions)
      if (row['businessPurpose'] == 'reimbursementAdvance' &&
          row['id'] is String)
        row['id'] as String,
  };
  final hasLegacyPurpose = sourceTransactions.any(
    (row) =>
        row['businessPurpose'] == 'reimbursementAdvance' ||
        row['businessPurpose'] == 'reimbursementReceipt' ||
        row['businessPurpose'] == 'reimbursementClose',
  );
  final hasLegacyRole = (tables['transaction_lines'] ?? const <BackupJson>[])
      .any(
        (row) =>
            row['role'] == 'reimbursementExpenseCategory' ||
            row['role'] == 'reimbursementGapIncome' ||
            row['role'] == 'reimbursementGapExpense',
      );
  final hasLegacyAccount = (tables['accounts'] ?? const <BackupJson>[]).any(
    (row) => row['systemKey'] == 'reimbursementGapIncome',
  );
  final hasLegacyOwnership = sourceTransactions.any(
    (row) =>
        row['ownerRole'] != null ||
        row['ownerType'] == 'advance.itemized' ||
        row['ownerType'] == 'advance.account' ||
        row['ownerType'] == 'installment' ||
        row['ownerType'] == 'credit_repayment',
  );

  if (hasLegacyPurpose) {
    final receivableByAdvanceId = <String, String>{};
    for (final row in tables['transaction_lines'] ?? const <BackupJson>[]) {
      final advanceId = row['transactionId'];
      final accountId = row['accountId'];
      if (advanceId is String &&
          advanceParentIds.contains(advanceId) &&
          row['role'] == 'receivable' &&
          accountId is String) {
        receivableByAdvanceId[advanceId] = accountId;
      }
    }
    final refundReceivableAccountIds = <String, String>{};
    for (final row in sourceTransactions) {
      final refundId = row['id'];
      final advanceId = row['parentTransactionId'];
      if (refundId is! String ||
          row['businessPurpose'] != 'refund' ||
          advanceId is! String) {
        continue;
      }
      final receivableAccountId = receivableByAdvanceId[advanceId];
      if (receivableAccountId != null) {
        refundReceivableAccountIds[refundId] = receivableAccountId;
      }
    }

    tables['transactions'] = [
      for (final source in sourceTransactions)
        _migrateTransaction(source, advanceParentIds),
    ];
    tables['transaction_lines'] = [
      for (final source in tables['transaction_lines'] ?? const <BackupJson>[])
        _migrateLine(
          source,
          refundReceivableAccountIds: refundReceivableAccountIds,
        ),
    ];
    tables['accounts'] = [
      for (final source in tables['accounts'] ?? const <BackupJson>[])
        _migrateAccount(source),
    ];
    if (tables.containsKey('account_groups')) {
      tables['account_groups'] = [
        for (final source in tables['account_groups']!)
          _migrateAccountGroup(source),
      ];
    }
  } else if (hasLegacyRole || hasLegacyAccount) {
    tables['transaction_lines'] = [
      for (final source in tables['transaction_lines'] ?? const <BackupJson>[])
        _migrateLine(source, refundReceivableAccountIds: const {}),
    ];
    tables['accounts'] = [
      for (final source in tables['accounts'] ?? const <BackupJson>[])
        _migrateAccount(source),
    ];
  }

  if (!hasLegacyOwnership && !hasLegacyPurpose) {
    tables.putIfAbsent('advance_cases', () => const <BackupJson>[]);
    return;
  }
  _migrateOwnership(tables);
}

void _migrateOwnership(Map<String, Iterable<BackupJson>> tables) {
  final transactions = [
    for (final source in tables['transactions'] ?? const <BackupJson>[])
      {...source},
  ];
  final lines = tables['transaction_lines'] ?? const <BackupJson>[];
  final casesById = <String, BackupJson>{
    for (final source in tables['advance_cases'] ?? const <BackupJson>[])
      if (source['id'] is String) source['id'] as String: {...source},
  };

  for (final parent in [...transactions]) {
    if (parent['ownerType'] != 'advance.itemized' ||
        parent['businessPurpose'] != 'advance' ||
        parent['ownerId'] is! String) {
      continue;
    }
    final ownerId = parent['ownerId'] as String;
    final scenario = _requiredScenario(parent['ownerRole']);
    final caseId = 'orchestration:advance:itemized:$ownerId';
    final advanceMinor = lines
        .where(
          (line) =>
              line['transactionId'] == ownerId && line['role'] == 'receivable',
        )
        .fold<int>(
          0,
          (total, line) => total + _intValueOrZero(line['amountMinor']),
        );
    casesById[caseId] = {
      'id': caseId,
      'scenario': scenario,
      'trackingMode': 'itemized',
      'receivableAccountId': null,
      'aaPeopleCount': scenario == 'aa'
          ? _inferAaPeopleCount(
              _intValueOrZero(parent['primaryAmountMinor']),
              advanceMinor,
            )
          : null,
      'createdAt': parent['createdAt'] ?? _migrationTimestamp,
      'updatedAt': parent['updatedAt'] ?? _migrationTimestamp,
    };
    for (final transaction in transactions) {
      if (transaction['ownerType'] == 'advance.itemized' &&
          transaction['ownerId'] == ownerId) {
        transaction['ownerType'] = 'orchestration.advance';
        transaction['ownerId'] = caseId;
      }
    }
  }

  for (final transaction in [...transactions]) {
    if (transaction['ownerType'] != 'advance.account' ||
        transaction['ownerId'] is! String) {
      continue;
    }
    final accountId = transaction['ownerId'] as String;
    final scenario = _requiredScenario(transaction['ownerRole']);
    final caseId = 'orchestration:advance:account:$scenario:$accountId';
    casesById[caseId] = {
      'id': caseId,
      'scenario': scenario,
      'trackingMode': 'account',
      'receivableAccountId': accountId,
      'aaPeopleCount': null,
      'createdAt': transaction['createdAt'] ?? _migrationTimestamp,
      'updatedAt': transaction['updatedAt'] ?? _migrationTimestamp,
    };
    for (final row in transactions) {
      if (row['ownerType'] == 'advance.account' &&
          row['ownerId'] == accountId &&
          row['ownerRole'] == scenario) {
        row['ownerType'] = 'orchestration.advance';
        row['ownerId'] = caseId;
      }
    }
  }

  for (final transaction in transactions) {
    transaction['ownerType'] = switch (transaction['ownerType']) {
      'installment' => 'credit.installment_contract',
      'credit_repayment' => 'credit.repayment',
      final value => value,
    };
    transaction.remove('ownerRole');
  }
  tables['transactions'] = transactions;
  tables['advance_cases'] = casesById.values.toList(growable: false);
}

BackupJson _migrateTransaction(
  BackupJson source,
  Set<String> advanceParentIds,
) {
  final row = {...source};
  row['businessPurpose'] = switch (row['businessPurpose']) {
    'reimbursementAdvance' => 'advance',
    'reimbursementReceipt' => 'advanceCollection',
    'reimbursementClose' => 'advanceSettlement',
    final value => value,
  };
  final id = row['id'];
  final parentId = row['parentTransactionId'];
  if (id is String &&
      (advanceParentIds.contains(id) || advanceParentIds.contains(parentId))) {
    row['ownerType'] = 'advance.itemized';
    row['ownerId'] = parentId is String ? parentId : id;
    row['ownerRole'] = 'reimbursement';
  }
  return row;
}

BackupJson _migrateLine(
  BackupJson source, {
  required Map<String, String> refundReceivableAccountIds,
}) {
  final row = {...source};
  final transactionId = row['transactionId'];
  if (row['role'] == 'refundOffset' &&
      transactionId is String &&
      refundReceivableAccountIds[transactionId] == row['accountId']) {
    row['role'] = 'receivable';
    return row;
  }
  row['role'] = switch (row['role']) {
    'reimbursementExpenseCategory' => 'advanceExpenseCategory',
    'reimbursementGapIncome' => 'advanceCompensationIncome',
    'reimbursementGapExpense' => 'advanceSelfBorne',
    final value => value,
  };
  return row;
}

BackupJson _migrateAccount(BackupJson source) {
  final row = {...source};
  if (row['systemKey'] == 'reimbursementGapIncome') {
    row['systemKey'] = 'advanceCompensationIncome';
    row['name'] = '垫付补偿';
  }
  return row;
}

BackupJson _migrateAccountGroup(BackupJson source) => source;

String _requiredScenario(Object? value) {
  if (value == 'aa' || value == 'onBehalf' || value == 'reimbursement') {
    return value! as String;
  }
  throw const BackupValidationException('旧垫付归属缺少有效场景。');
}

int _intValueOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int _inferAaPeopleCount(int totalMinor, int advanceMinor) {
  for (var people = 2; people <= 99; people++) {
    final perPersonMinor = (totalMinor + people - 1) ~/ people;
    if (perPersonMinor * (people - 1) == advanceMinor) return people;
  }
  final selfBorneMinor = totalMinor - advanceMinor;
  if (selfBorneMinor <= 0 || totalMinor <= 0) return 2;
  return (totalMinor / selfBorneMinor).round().clamp(2, 99);
}

const _migrationTimestamp = '1970-01-01T00:00:00.000Z';
