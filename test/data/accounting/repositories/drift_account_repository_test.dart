import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/accounting/repositories/drift_account_repository.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import 'package:smartflow/domain/accounting/services/account_service.dart';
import 'package:smartflow/domain/accounting/services/category_service.dart';

import '../../../helpers/test_app_database.dart';

void main() {
  group('DriftAccountRepository', () {
    late AppDatabase database;
    late DriftAccountRepository repository;

    setUp(() {
      database = createTestDatabase();
      repository = DriftAccountRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates an account with opening balance in one posting chain',
      () async {
        final service = AccountServiceImpl(repository);

        final result = await service.createAccount(
          CreateAccountCommand(
            name: '招行',
            type: AccountType.asset,
            openingBalance: const Money(minorUnits: 5000000),
            openingOccurredAt: DateTime(2026, 5),
          ),
        );

        expect(result, isA<Success>());
        final account = (result as Success).value;
        expect(account.balance, const Money(minorUnits: 5000000));

        final transactions = await database.select(database.transactions).get();
        final details =
            await database.select(database.transactionDetails).get();
        final entries = await database.select(database.entries).get();
        final systemAccounts =
            await (database.select(database.accounts)..where(
              (row) => row.systemKey.equalsValue(SystemKey.openingBalance),
            )).get();

        expect(transactions, hasLength(1));
        expect(
          transactions.single.businessPurpose,
          BusinessPurpose.openingBalance,
        );
        expect(
          details.single.detailType,
          TransactionDetailType.openingBalanceMain,
        );
        expect(entries, hasLength(2));
        expect(systemAccounts.single.accountType, AccountType.equity);
        expect(systemAccounts.single.balanceMinor, 5000000);
      },
    );

    test('edits fund account balance through balance adjustment', () async {
      final service = AccountServiceImpl(repository);
      final createResult = await service.createAccount(
        CreateAccountCommand(
          name: '招行',
          type: AccountType.asset,
          openingBalance: const Money(minorUnits: 500000),
          openingOccurredAt: DateTime(2026, 5),
        ),
      );
      final account = (createResult as Success).value;

      final editResult = await service.editAccount(
        EditAccountCommand(
          id: account.id,
          name: '招商银行',
          targetBalance: const Money(minorUnits: 700000),
          balanceAdjustmentOccurredAt: DateTime(2026, 5, 2),
        ),
      );

      expect(editResult, isA<Success>());
      final updated = await repository.findAccountById(account.id);
      expect(updated!.name, '招商银行');
      expect(updated.balance, const Money(minorUnits: 700000));

      final transactions =
          await (database.select(database.transactions)..where(
            (row) => row.businessPurpose.equalsValue(
              BusinessPurpose.balanceAdjustment,
            ),
          )).get();
      final details =
          await (database.select(database.transactionDetails)..where(
            (row) => row.detailType.equalsValue(
              TransactionDetailType.balanceAdjustmentMain,
            ),
          )).get();

      expect(transactions, hasLength(1));
      expect(transactions.single.primaryAmountMinor, 200000);
      expect(details.single.amountMinor, 200000);
    });

    test('edits credit account debt through balance adjustment', () async {
      final service = AccountServiceImpl(repository);
      final createResult = await service.createAccount(
        CreateAccountCommand(
          name: '花呗',
          type: AccountType.liability,
          subtype: AccountSubtype.consumerCredit,
          openingBalance: const Money(minorUnits: 1000000),
          openingOccurredAt: DateTime(2026, 5),
        ),
      );
      final account = (createResult as Success).value;

      final editResult = await service.editAccount(
        EditAccountCommand(
          id: account.id,
          name: '花呗',
          targetBalance: const Money(minorUnits: 800000),
          balanceAdjustmentOccurredAt: DateTime(2026, 5, 2),
        ),
      );

      expect(editResult, isA<Success>());
      final updated = await repository.findAccountById(account.id);
      expect(updated!.balance, const Money(minorUnits: 800000));

      final adjustmentEntries =
          await (database.select(database.entries).join([
            innerJoin(
              database.transactions,
              database.transactions.id.equalsExp(
                database.entries.transactionId,
              ),
            ),
          ])..where(
            database.transactions.businessPurpose.equalsValue(
              BusinessPurpose.balanceAdjustment,
            ),
          )).get();
      final liabilityEntry = adjustmentEntries
          .map((row) => row.readTable(database.entries))
          .singleWhere((entry) => entry.accountId == account.id);

      expect(liabilityEntry.direction, EntryDirection.debit);
      expect(liabilityEntry.amountMinor, 200000);
    });

    test(
      'allows loan account opening balance and balance adjustment',
      () async {
        final service = AccountServiceImpl(repository);

        final createResult = await service.createAccount(
          CreateAccountCommand(
            name: '房贷',
            type: AccountType.liability,
            subtype: AccountSubtype.loan,
            openingBalance: const Money(minorUnits: 1000000),
            openingOccurredAt: DateTime(2026, 5),
          ),
        );
        expect(createResult, isA<Success>());
        final account = (createResult as Success).value;
        final afterCreate = await repository.findAccountById(account.id);
        expect(afterCreate!.balance, const Money(minorUnits: 1000000));

        final editResult = await service.editAccount(
          EditAccountCommand(
            id: account.id,
            name: account.name,
            subtype: account.subtype,
            targetBalance: const Money(minorUnits: 800000),
            balanceAdjustmentOccurredAt: DateTime(2026, 5, 2),
          ),
        );
        expect(editResult, isA<Success>());
        final afterEdit = await repository.findAccountById(account.id);
        expect(afterEdit!.balance, const Money(minorUnits: 800000));
      },
    );

    test('creates reimbursement account as asset subtype', () async {
      final service = AccountServiceImpl(repository);

      final result = await service.createAccount(
        const CreateAccountCommand(
          name: '公司报销',
          type: AccountType.asset,
          subtype: AccountSubtype.reimbursement,
        ),
      );

      expect(result, isA<Success>());
      final account = (result as Success).value;
      expect(account.type, AccountType.asset);
      expect(account.subtype, AccountSubtype.reimbursement);
    });

    test('builds income and expense category trees', () async {
      final service = CategoryServiceImpl(repository);
      final parentResult = await service.createCategory(
        const CreateCategoryCommand(name: '餐饮', type: AccountType.expense),
      );
      final parent = (parentResult as Success).value;

      await service.createCategory(
        CreateCategoryCommand(
          name: '咖啡',
          type: AccountType.expense,
          parentId: parent.id,
        ),
      );

      final tree = await service.watchCategoryTree(AccountType.expense).first;

      final node = tree.singleWhere((node) => node.account.name == '餐饮');
      expect(node.children.single.name, '咖啡');
    });
  });
}
