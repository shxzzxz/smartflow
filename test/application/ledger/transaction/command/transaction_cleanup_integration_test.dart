import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/shared/uuid_id_generator.dart';

import '../../../../helper/test_app_database.dart';
import '../../../../helper/fake_transaction_tag_repository.dart';

void main() {
  late AppDatabase database;
  late DriftAccountRepository accounts;
  late TransactionCleanupAppServiceImpl service;

  setUp(() async {
    database = createTestDatabase();
    final runner = DriftTransactionRunner(database);
    final postingRepository = DriftPostingRepository(database);
    accounts = DriftAccountRepository(database);
    final editService = TransactionEditAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: postingRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      ledgerWriter: TransactionLedgerWriter(
        transactionRunner: runner,
        transactionRepository: postingRepository,
        transactionGroupRepository: postingRepository,
        accountRepository: accounts,
        transactionTagRepository: FakeTransactionTagRepository(),
      ),
      idGenerator: const UuidIdGenerator(),
    );
    service = TransactionCleanupAppServiceImpl(
      transactionRunner: runner,
      transactionReadRepository: DriftTransactionReadRepository(database),
      editService: editService,
    );

    final cash = Account(
      id: 'acc-cash',
      name: '现金',
      type: AccountType.asset,
      balance: const Money(minorUnits: 10000),
    );
    final bank = Account(
      id: 'acc-bank',
      name: '银行卡',
      type: AccountType.liability,
      balance: const Money(minorUnits: 5000),
    );
    final food = Account(
      id: 'cat-food',
      name: '餐饮',
      type: AccountType.expense,
      balance: const Money(minorUnits: 3000),
    );
    await accounts.create(cash);
    await accounts.create(bank);
    await accounts.create(food);
    // create 固定落 0 余额，改用 save 写入测试所需的初始余额。
    await accounts.saveAll([cash, bank, food]);

    await postingRepository.saveAll([
      _transaction(
        id: 'expense-cash',
        occurredAt: DateTime(2026, 6, 10),
        amountMinor: 1000,
        debitAccountId: 'cat-food',
        creditAccountId: 'acc-cash',
      ),
      _transaction(
        id: 'expense-bank',
        occurredAt: DateTime(2026, 7, 10),
        amountMinor: 2000,
        debitAccountId: 'cat-food',
        creditAccountId: 'acc-bank',
      ),
      _transaction(
        id: 'expense-bank-refund',
        parentId: 'expense-bank',
        occurredAt: DateTime(2026, 7, 12),
        amountMinor: 300,
        debitAccountId: 'acc-cash',
        creditAccountId: 'cat-food',
      ),
      _transaction(
        id: 'owned-transfer',
        occurredAt: DateTime(2026, 7, 15),
        amountMinor: 500,
        debitAccountId: 'acc-cash',
        creditAccountId: 'acc-bank',
        businessPurpose: BusinessPurpose.transfer,
        ownership: const TransactionOwnership(ownerType: 'credit_repayment'),
      ),
    ]);
  });

  tearDown(() async {
    await database.close();
  });

  test('清理删除整组交易并回冲余额，跳过带业务归属的交易组', () async {
    final result = await service.cleanupTransactions(
      const CleanupTransactionsCommand(categoryIds: {'cat-food'}),
    );

    expect(result.deletedGroupCount, 2);
    expect(result.skippedGroupCount, 0);

    final remaining = await database
        .customSelect('SELECT id FROM transactions ORDER BY id')
        .get();
    expect(remaining.map((row) => row.read<String>('id')), ['owned-transfer']);
    final remainingEntries = await database
        .customSelect('SELECT COUNT(*) AS count FROM entries')
        .getSingle();
    expect(remainingEntries.read<int>('count'), 2);

    // 现金：+1000（删支出贷方）-300（删退款借方）；银行卡（负债）：-2000（删贷方）；
    // 餐饮（支出）：-1000 -2000 +300。
    expect(
      (await accounts.findById('acc-cash'))!.balance,
      const Money(minorUnits: 10700),
    );
    expect(
      (await accounts.findById('acc-bank'))!.balance,
      const Money(minorUnits: 3000),
    );
    expect(
      (await accounts.findById('cat-food'))!.balance,
      const Money(minorUnits: 300),
    );
  });

  test('带业务归属的交易组保持原样并计入跳过', () async {
    final result = await service.cleanupTransactions(
      const CleanupTransactionsCommand(accountIds: {'acc-cash', 'acc-bank'}),
    );

    expect(result.deletedGroupCount, 2);
    expect(result.skippedGroupCount, 1);

    final remaining = await database
        .customSelect('SELECT id FROM transactions ORDER BY id')
        .get();
    expect(remaining.map((row) => row.read<String>('id')), ['owned-transfer']);
    expect(
      (await accounts.findById('acc-cash'))!.balance,
      const Money(minorUnits: 10700),
    );
  });
}

Transaction _transaction({
  required String id,
  required DateTime occurredAt,
  required int amountMinor,
  required String debitAccountId,
  required String creditAccountId,
  BusinessPurpose? businessPurpose,
  String? parentId,
  TransactionOwnership? ownership,
}) {
  final amount = Money(minorUnits: amountMinor);
  final purpose =
      businessPurpose ??
      (parentId == null
          ? BusinessPurpose.dailyExpense
          : BusinessPurpose.refund);
  return Transaction(
    id: id,
    businessPurpose: purpose,
    occurredAt: occurredAt,
    primaryAmount: amount,
    parentTransactionId: parentId,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    ownership: ownership,
    lines: [
      TransactionLine(
        id: 'line-$id-first',
        transactionId: id,
        lineNo: 1,
        role: purpose == BusinessPurpose.dailyExpense
            ? TransactionRole.category
            : TransactionRole.settlementIn,
        accountId: debitAccountId,
        amount: amount,
      ),
      TransactionLine(
        id: 'line-$id-second',
        transactionId: id,
        lineNo: 2,
        role: purpose == BusinessPurpose.refund
            ? TransactionRole.refundOffset
            : TransactionRole.settlementOut,
        accountId: creditAccountId,
        amount: amount,
      ),
    ],
    entries: [
      Entry(
        id: 'entry-$id-debit',
        transactionId: id,
        accountId: debitAccountId,
        direction: EntryDirection.debit,
        amount: amount,
      ),
      Entry(
        id: 'entry-$id-credit',
        transactionId: id,
        accountId: creditAccountId,
        direction: EntryDirection.credit,
        amount: amount,
      ),
    ],
  );
}
