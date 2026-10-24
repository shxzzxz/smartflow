import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/data_management/backup/advance_backup_migration.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';

void main() {
  test('migrates legacy reimbursement rows to itemized advances', () {
    final tables = <String, Iterable<BackupJson>>{
      'transactions': [
        {
          'id': 'advance',
          'businessPurpose': 'reimbursementAdvance',
          'parentTransactionId': null,
        },
        {
          'id': 'receipt',
          'businessPurpose': 'reimbursementReceipt',
          'parentTransactionId': 'advance',
        },
      ],
      'transaction_lines': [
        {'id': 'category', 'role': 'reimbursementExpenseCategory'},
        {'id': 'gap', 'role': 'reimbursementGapExpense'},
        {'id': 'income', 'role': 'reimbursementGapIncome'},
      ],
      'accounts': [
        {
          'id': 'advance-account',
          'name': '垫付应收',
          'accountProfileKey': 'ledger.reimbursement',
          'groupId': 'builtin-account-group-reimbursement',
          'systemKey': null,
        },
        {
          'id': 'income',
          'name': '报销差额收入',
          'systemKey': 'reimbursementGapIncome',
        },
      ],
      'account_groups': [
        {'id': 'builtin-account-group-reimbursement', 'name': '报销'},
      ],
    };

    migrateAdvanceBackup(tables);

    expect(tables['transactions'], [
      {
        'id': 'advance',
        'businessPurpose': 'advance',
        'parentTransactionId': null,
        'ownerType': 'advance.itemized',
        'ownerId': 'advance',
        'ownerRole': 'reimbursement',
      },
      {
        'id': 'receipt',
        'businessPurpose': 'advanceCollection',
        'parentTransactionId': 'advance',
        'ownerType': 'advance.itemized',
        'ownerId': 'advance',
        'ownerRole': 'reimbursement',
      },
    ]);
    expect(tables['transaction_lines']!.map((row) => row['role']), [
      'advanceExpenseCategory',
      'advanceSelfBorne',
      'advanceCompensationIncome',
    ]);
    expect(tables['accounts'], [
      {
        'id': 'advance-account',
        'name': '垫付应收',
        'accountProfileKey': 'ledger.reimbursement',
        'groupId': 'builtin-account-group-reimbursement',
        'systemKey': null,
      },
      {
        'id': 'income',
        'name': '垫付补偿',
        'systemKey': 'advanceCompensationIncome',
      },
    ]);
    expect(tables['account_groups'], [
      {'id': 'builtin-account-group-reimbursement', 'name': '报销'},
    ]);
  });

  test('migrates only advance refund offsets to receivable', () {
    final tables = <String, Iterable<BackupJson>>{
      'transactions': [
        {
          'id': 'advance',
          'businessPurpose': 'reimbursementAdvance',
          'parentTransactionId': null,
        },
        {
          'id': 'advance-refund',
          'businessPurpose': 'refund',
          'parentTransactionId': 'advance',
        },
        {
          'id': 'expense',
          'businessPurpose': 'dailyExpense',
          'parentTransactionId': null,
        },
        {
          'id': 'expense-refund',
          'businessPurpose': 'refund',
          'parentTransactionId': 'expense',
        },
      ],
      'transaction_lines': [
        {
          'id': 'advance-receivable',
          'transactionId': 'advance',
          'role': 'receivable',
          'accountId': 'advance-account',
        },
        {
          'id': 'advance-refund-category',
          'transactionId': 'advance-refund',
          'role': 'reimbursementExpenseCategory',
          'accountId': 'travel',
        },
        {
          'id': 'advance-refund-offset',
          'transactionId': 'advance-refund',
          'role': 'refundOffset',
          'accountId': 'advance-account',
        },
        {
          'id': 'expense-refund-offset',
          'transactionId': 'expense-refund',
          'role': 'refundOffset',
          'accountId': 'travel',
        },
      ],
    };

    migrateAdvanceBackup(tables);

    expect(
      {for (final row in tables['transaction_lines']!) row['id']: row['role']},
      {
        'advance-receivable': 'receivable',
        'advance-refund-category': 'advanceExpenseCategory',
        'advance-refund-offset': 'receivable',
        'expense-refund-offset': 'refundOffset',
      },
    );
  });
}
