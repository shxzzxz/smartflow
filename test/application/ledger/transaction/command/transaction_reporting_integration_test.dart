import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_budget_query_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_tag_repository.dart';

import '../../../../helper/sequential_id_generator.dart';
import '../../../../helper/test_app_database.dart';
import '../../../../helper/fake_counterparty_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPostingRepository transactions;
  late TransactionPostingAppService posting;
  late TransactionEditAppService editing;
  late TransactionUpdateAppService updates;
  late DriftTransactionTagRepository tags;
  late DriftLedgerMetricsSource metrics;
  final date = DateTime(2026, 10, 17);
  final window = DateTimeWindow(
    from: DateTime(2026, 10),
    until: DateTime(2026, 11),
  );

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    for (final (id, type, subtype, profile) in [
      ('cash', AccountType.asset, AccountSubtype.fund, 'ledger.fund'),
      ('bank', AccountType.asset, AccountSubtype.fund, 'ledger.fund'),
      ('loan', AccountType.liability, AccountSubtype.loan, 'credit.loan'),
      (
        'receivable',
        AccountType.asset,
        AccountSubtype.receivable,
        'ledger.receivable',
      ),
      ('food', AccountType.expense, null, null),
    ]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              name: id,
              accountType: type,
              accountSubtype: Value(subtype),
              accountProfileKey: Value(profile),
            ),
          );
    }
    transactions = DriftPostingRepository(db);
    final accounts = DriftAccountRepository(db);
    tags = DriftTransactionTagRepository(db);
    await tags.insertTag(id: 'travel', name: '旅行');
    final writer = TransactionLedgerWriter(
      transactionRunner: DriftTransactionRunner(db),
      transactionRepository: transactions,
      transactionGroupRepository: transactions,
      accountRepository: accounts,
      transactionTagRepository: tags,
      counterpartyRepository: FakeCounterpartyRepository(),
    );
    final ids = SequentialIdGenerator(prefix: 'reporting');
    final systems = DriftSystemAccountResolver(db);
    posting = TransactionPostingAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: systems,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    editing = TransactionEditAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: systems,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    updates = TransactionUpdateAppServiceImpl(
      transactionRepository: transactions,
      transactionGroupRepository: transactions,
      ledgerWriter: writer,
    );
    metrics = DriftLedgerMetricsSource(db);
  });

  Future<void> expectReporting(
    int expense,
    int budget, {
    int income = 0,
  }) async {
    const types = {AccountType.income, AccountType.expense};
    final totals = await metrics.aggregateByAccountType(
      accountTypes: types,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(totals[AccountType.expense] ?? 0, expense);
    expect(totals[AccountType.income] ?? 0, income);
    final categories = await metrics.aggregateByAccount(
      accountTypes: types,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(
      categories
          .where((row) => row.accountType == AccountType.expense)
          .fold<int>(0, (sum, row) => sum + row.amountMinor),
      expense,
    );
    final daily = await metrics.aggregateByAccountTypeByDay(
      accountTypes: types,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(
      daily.values.fold<int>(
        0,
        (sum, row) => sum + (row[AccountType.expense] ?? 0),
      ),
      expense,
    );
    final monthly = await metrics.aggregateByAccountTypeByMonth(
      accountTypes: types,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(
      monthly.values.fold<int>(
        0,
        (sum, row) => sum + (row[AccountType.expense] ?? 0),
      ),
      expense,
    );
    final tagged = await metrics.aggregateByTag(
      accountTypes: types,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(
      tagged
          .where((row) => row.accountType == AccountType.expense)
          .fold<int>(0, (sum, row) => sum + row.amountMinor),
      expense,
    );
    expect(
      tagged
          .where((row) => row.accountType == AccountType.income)
          .fold<int>(0, (sum, row) => sum + row.amountMinor),
      income,
    );
    final usage = await DriftBudgetQuerySource(
      db,
    ).watchMonth(MonthKey(year: 2026, month: 10)).first;
    expect(
      usage.dailyUsage.fold<int>(0, (sum, row) => sum + row.amountMinor),
      budget,
    );
  }

  for (final repayment in [false, true]) {
    test(
      '${repayment ? "owned repayment" : "transfer"} counts only fees and interest',
      () async {
        final result = repayment
            ? await posting.createRepayment(
                CreateRepaymentCommand(
                  principal: Money.parse('100'),
                  interest: Money.parse('3'),
                  fee: Money.parse('2'),
                  liabilityAccountId: 'loan',
                  paidFromAccountId: 'cash',
                  occurredAt: date,
                  ownership: const TransactionOwnership(
                    ownerType: 'credit.repayment',
                    ownerId: 'repayment',
                  ),
                ),
              )
            : await posting.createTransfer(
                CreateTransferCommand(
                  amount: Money.parse('100'),
                  feeAmount: Money.parse('5'),
                  fromAccountId: 'cash',
                  toAccountId: 'bank',
                  occurredAt: date,
                ),
              );
        await updates.updateTags(
          UpdateTransactionTagsCommand(
            transactionId: result.transactionId,
            tagIds: {'travel'},
          ),
        );
        final original = await transactions.findCompleteById(
          result.transactionId,
        );
        final balances = {
          for (final row in await db.select(db.accounts).get())
            row.id: row.balanceMinor,
        };
        for (final (stats, budget, expenseExpected, budgetExpected) in [
          (false, false, 500, 500),
          (true, false, 0, 500),
          (false, true, 500, 0),
          (true, true, 0, 0),
        ]) {
          await updates.updateReportingFlag(
            UpdateTransactionReportingFlagCommand(
              transactionId: result.transactionId,
              isExcludedFromStats: stats,
              isExcludedFromBudget: budget,
            ),
          );
          await expectReporting(expenseExpected, budgetExpected);
          final current = await transactions.findCompleteById(
            result.transactionId,
          );
          expect(current!.isExcludedFromStats, stats);
          expect(current.isExcludedFromBudget, budget);
          expect(current.hasSameAccountingExpressionAs(original!), isTrue);
          expect({
            for (final row in await db.select(db.accounts).get())
              row.id: row.balanceMinor,
          }, balances);
        }
        if (repayment) {
          await editing.editRepayment(
            EditRepaymentCommand(
              transactionId: result.transactionId,
              paidFromAccountId: 'bank',
            ),
          );
        } else {
          await editing.editTransfer(
            EditTransferCommand(
              transactionId: result.transactionId,
              amount: Money.parse('120'),
            ),
          );
        }
        final edited = await transactions.findCompleteById(
          result.transactionId,
        );
        expect(edited!.isExcludedFromStats, isTrue);
        expect(edited.isExcludedFromBudget, isTrue);
        expect(edited.ownership?.ownerType, original!.ownership?.ownerType);
        expect(edited.ownership?.ownerId, original.ownership?.ownerId);
        expect(await tags.transactionTagIds(result.transactionId), {'travel'});
        await expectReporting(0, 0);
      },
    );
  }

  test(
    'repayment discount income remains separate from interest and fee expenses',
    () async {
      final result = await posting.createRepayment(
        CreateRepaymentCommand(
          principal: Money.parse('100'),
          interest: Money.parse('3'),
          fee: Money.parse('2'),
          discount: Money.parse('1'),
          liabilityAccountId: 'loan',
          paidFromAccountId: 'cash',
          occurredAt: date,
        ),
      );
      await updates.updateTags(
        UpdateTransactionTagsCommand(
          transactionId: result.transactionId,
          tagIds: {'travel'},
        ),
      );
      await expectReporting(500, 500, income: 100);
      await updates.updateReportingFlag(
        UpdateTransactionReportingFlagCommand(
          transactionId: result.transactionId,
          isExcludedFromBudget: true,
        ),
      );
      await expectReporting(500, 0, income: 100);
      await updates.updateReportingFlag(
        UpdateTransactionReportingFlagCommand(
          transactionId: result.transactionId,
          isExcludedFromStats: true,
        ),
      );
      await expectReporting(0, 0);
    },
  );

  test('pure transfer retains flags when a fee is later added', () async {
    final result = await posting.createTransfer(
      CreateTransferCommand(
        amount: Money.parse('100'),
        fromAccountId: 'cash',
        toAccountId: 'bank',
        occurredAt: date,
      ),
    );
    await updates.updateReportingFlag(
      UpdateTransactionReportingFlagCommand(
        transactionId: result.transactionId,
        isExcludedFromStats: true,
      ),
    );
    await expectReporting(0, 0);
    await editing.editTransfer(
      EditTransferCommand(
        transactionId: result.transactionId,
        feeAmount: Money.parse('5'),
      ),
    );
    await expectReporting(0, 500);
    await updates.updateReportingFlag(
      UpdateTransactionReportingFlagCommand(
        transactionId: result.transactionId,
        isExcludedFromStats: false,
      ),
    );
    await expectReporting(500, 500);
  });

  test(
    'refund follows group flags and cannot update flags or tags independently',
    () async {
      final parent = await posting.createExpense(
        CreateExpenseCommand(
          amount: Money.parse('100'),
          occurredAt: date,
          categoryAllocations: singleAllocation(
            accountId: 'food',
            amount: Money.parse('100'),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('100'),
          ),
        ),
      );
      await updates.updateTags(
        UpdateTransactionTagsCommand(
          transactionId: parent.transactionId,
          tagIds: {'travel'},
        ),
      );
      Future<PostedTransactionResult> refund(String amount) =>
          posting.createRefund(
            CreateRefundCommand(
              parentTransactionId: parent.transactionId,
              amount: Money.parse(amount),
              occurredAt: date,
              categoryAllocations: singleAllocation(
                accountId: 'food',
                amount: Money.parse(amount),
              ),
              settlementAllocations: singleAllocation(
                accountId: 'bank',
                amount: Money.parse(amount),
              ),
            ),
          );
      final child = await refund('20');
      await expectReporting(8000, 8000);
      await updates.updateReportingFlag(
        UpdateTransactionReportingFlagCommand(
          transactionId: parent.transactionId,
          isExcludedFromStats: true,
          isExcludedFromBudget: true,
        ),
      );
      expect(
        (await transactions.findById(child.transactionId))!.isExcludedFromStats,
        isTrue,
      );
      expect(
        (await transactions.findById(
          child.transactionId,
        ))!.isExcludedFromBudget,
        isTrue,
      );
      await expectReporting(0, 0);
      await expectLater(
        updates.updateReportingFlag(
          UpdateTransactionReportingFlagCommand(
            transactionId: child.transactionId,
            isExcludedFromStats: false,
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        updates.updateTags(
          UpdateTransactionTagsCommand(
            transactionId: child.transactionId,
            tagIds: {},
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(await tags.transactionTagIds(child.transactionId), {'travel'});
      final later = await refund('10');
      expect(
        (await transactions.findById(
          later.transactionId,
        ))!.isExcludedFromBudget,
        isTrue,
      );
      await updates.updateReportingFlag(
        UpdateTransactionReportingFlagCommand(
          transactionId: parent.transactionId,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
        ),
      );
      await expectReporting(7000, 7000);
      final rows = await DriftTransactionReadRepository(db)
          .watchPage(
            TransactionPageQuery(
              match: const TransactionImpactMatch(categoryAccountIds: {'food'}),
              scope: TransactionScopeFilter.stats,
              topLevelOnly: false,
              limit: null,
            ),
          )
          .first;
      expect(rows.map((row) => row.id).toSet(), {
        parent.transactionId,
        child.transactionId,
        later.transactionId,
      });
    },
  );

  test(
    'closed advance allows metadata and receipt account changes but keeps amounts locked',
    () async {
      final parent = await posting.createAdvance(
        CreateAdvanceCommand(
          amount: Money.parse('100'),
          receivableAccountId: 'receivable',
          occurredAt: date,
          categoryAllocations: singleAllocation(
            accountId: 'food',
            amount: Money.parse('100'),
          ),
          selfBorneAllocations: const [],
          ownership: const TransactionOwnership(
            ownerType: 'orchestration.advance',
            ownerId: 'advance-case',
          ),
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('100'),
          ),
        ),
      );
      final receipt = await posting.createAdvanceCollection(
        CreateAdvanceCollectionCommand(
          advanceTransactionId: parent.transactionId,
          amount: Money.parse('60'),
          receivableAccountId: 'receivable',
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('60'),
          ),
          occurredAt: date,
        ),
      );
      final refund = await posting.createRefund(
        CreateRefundCommand(
          parentTransactionId: parent.transactionId,
          amount: Money.parse('20'),
          occurredAt: date,
          categoryAllocations: singleAllocation(
            accountId: 'food',
            amount: Money.parse('20'),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('20'),
          ),
        ),
      );
      await posting.settleAdvance(
        CreateAdvanceSettlementCommand(
          advanceTransactionId: parent.transactionId,
          actualReceivedAmount: Money.parse('20'),
          receivableAccountId: 'receivable',
          occurredAt: date,
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('20'),
          ),
          gapExpenseAllocations: const [],
        ),
      );
      await updates.updateBasicInfo(
        UpdateTransactionBasicInfoCommand(
          transactionId: receipt.transactionId,
          occurredAt: date.add(const Duration(hours: 1)),
        ),
      );
      await editing.editAdvanceCollection(
        EditAdvanceCollectionCommand(
          transactionId: receipt.transactionId,
          settlementAllocations: singleAllocation(
            accountId: 'bank',
            amount: Money.parse('60'),
          ),
        ),
      );
      await editing.editRefund(
        EditRefundCommand(
          transactionId: refund.transactionId,
          settlementAllocations: singleAllocation(
            accountId: 'bank',
            amount: Money.parse('20'),
          ),
        ),
      );
      final group = await transactions.findByTransactionId(
        parent.transactionId,
      );
      expect(group!.advanceSettled, isTrue);
      expect(
        (await transactions.findCompleteById(
          receipt.transactionId,
        ))!.accountOf(TransactionRole.settlementIn),
        'bank',
      );
      expect(
        (await transactions.findCompleteById(
          refund.transactionId,
        ))!.accountOf(TransactionRole.settlementIn),
        'bank',
      );
      await expectLater(
        editing.editAdvanceCollection(
          EditAdvanceCollectionCommand(
            transactionId: receipt.transactionId,
            amount: Money.parse('61'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        editing.editRefund(
          EditRefundCommand(
            transactionId: refund.transactionId,
            amount: Money.parse('21'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        editing.deleteTransaction(
          DeleteTransactionCommand(transactionId: receipt.transactionId),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'account-managed receipt edit persists a top-level transaction',
    () async {
      const ownership = TransactionOwnership(
        ownerType: 'orchestration.advance',
        ownerId: 'advance-case',
      );
      final receipt = await posting.createAdvanceCollection(
        CreateAdvanceCollectionCommand.account(
          amount: Money.parse('40'),
          receivableAccountId: 'receivable',
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('40'),
          ),
          occurredAt: date,
          ownership: ownership,
        ),
      );

      await editing.editAdvanceCollection(
        EditAdvanceCollectionCommand(
          transactionId: receipt.transactionId,
          amount: Money.parse('45'),
          settlementAllocations: singleAllocation(
            accountId: 'bank',
            amount: Money.parse('45'),
          ),
        ),
      );

      final rewritten = (await transactions.findCompleteById(
        receipt.transactionId,
      ))!;
      expect(rewritten.id, receipt.transactionId);
      expect(rewritten.parentTransactionId, null);
      expect(rewritten.primaryAmount, Money.parse('45'));
      expect(rewritten.ownership?.ownerType, 'orchestration.advance');
      expect(rewritten.ownership?.ownerId, 'advance-case');
      expect(rewritten.accountOf(TransactionRole.settlementIn), 'bank');
      expect(rewritten.amountOf(TransactionRole.receivable), Money.parse('45'));
    },
  );

  test(
    'account-managed settlement edit persists a top-level transaction',
    () async {
      const ownership = TransactionOwnership(
        ownerType: 'orchestration.advance',
        ownerId: 'advance-case',
      );
      final close = await posting.settleAdvance(
        CreateAdvanceSettlementCommand.account(
          actualReceivedAmount: Money.parse('60'),
          receivableAccountId: 'receivable',
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: Money.parse('60'),
          ),
          gapExpenseAllocations: const [],
          ownership: ownership,
          occurredAt: date,
        ),
      );

      await editing.editAdvanceSettlement(
        EditAdvanceSettlementCommand(
          transactionId: close.transactionId,
          actualReceivedAmount: Money.parse('70'),
          settlementAllocations: singleAllocation(
            accountId: 'bank',
            amount: Money.parse('70'),
          ),
          gapExpenseAllocations: const [],
        ),
      );

      final rewritten = (await transactions.findCompleteById(
        close.transactionId,
      ))!;
      expect(rewritten.id, close.transactionId);
      expect(rewritten.parentTransactionId, null);
      expect(rewritten.primaryAmount, Money.parse('70'));
      expect(rewritten.ownership?.ownerType, 'orchestration.advance');
      expect(rewritten.ownership?.ownerId, 'advance-case');
      expect(rewritten.accountOf(TransactionRole.settlementIn), 'bank');
      expect(rewritten.amountOf(TransactionRole.receivable), Money.parse('70'));
      expect(rewritten.linesOf(TransactionRole.advanceSelfBorne), isEmpty);
    },
  );

  test('advance conversion and amount edits preserve group flags', () async {
    final parent = await posting.createExpense(
      CreateExpenseCommand(
        amount: Money.parse('100'),
        occurredAt: date,
        categoryAllocations: singleAllocation(
          accountId: 'food',
          amount: Money.parse('100'),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: Money.parse('100'),
        ),
      ),
    );
    await updates.updateReportingFlag(
      UpdateTransactionReportingFlagCommand(
        transactionId: parent.transactionId,
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
      ),
    );
    await editing.editAdvance(
      EditAdvanceCommand(
        transactionId: parent.transactionId,
        receivableAccountId: 'receivable',
      ),
    );
    final advanced = await transactions.findById(parent.transactionId);
    expect(advanced!.isExcludedFromStats, isTrue);
    expect(advanced.isExcludedFromBudget, isTrue);
    await editing.editExpense(
      EditExpenseCommand(transactionId: parent.transactionId),
    );
    await editing.editExpense(
      EditExpenseCommand(
        transactionId: parent.transactionId,
        amount: Money.parse('120'),
      ),
    );
    await expectReporting(0, 0);
    await updates.updateReportingFlag(
      UpdateTransactionReportingFlagCommand(
        transactionId: parent.transactionId,
        isExcludedFromStats: false,
      ),
    );
    await expectReporting(12000, 0);
  });
}
