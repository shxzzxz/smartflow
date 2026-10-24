import 'backup_models.dart';

/// Migrates pre-v48 backups to the generalized advance vocabulary.
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
  if (!hasLegacyPurpose && !hasLegacyRole && !hasLegacyAccount) return;

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
