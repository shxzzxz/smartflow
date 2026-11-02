import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/port/amortization_ledger_port.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/orchestration/amortization_ledger_port.dart';
import 'package:smartflow/infrastructure/orchestration/repository/drift_amortization_repository.dart';

import '../../helper/fake_counterparty_repository.dart';
import '../../helper/fake_transaction_tag_repository.dart';
import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  test('prepaid and deferred plans post real balanced ledger facts', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);

    final prepaidId = await fixture.service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: _money(300000),
        fundingAllocations: const [
          AccountAmountAllocation(
            accountId: 'fund',
            amount: Money(minorUnits: 100000),
          ),
          AccountAmountAllocation(
            accountId: 'fund-2',
            amount: Money(minorUnits: 200000),
          ),
        ],
        deferralAccountId: 'prepaid',
        recognitionAllocations: const [
          AccountAmountAllocation(
            accountId: 'rent-expense',
            amount: Money(minorUnits: 200000),
          ),
          AccountAmountAllocation(
            accountId: 'utilities-expense',
            amount: Money(minorUnits: 100000),
          ),
        ],
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await fixture.service.generateDue(DateTime(2026, 1, 31));

    expect(await fixture.balance('fund'), _money(-100000));
    expect(await fixture.balance('fund-2'), _money(-200000));
    expect(await fixture.balance('prepaid'), _money(200000));
    expect(await fixture.balance('rent-expense'), _money(66667));
    expect(await fixture.balance('utilities-expense'), _money(33333));

    await fixture.service.terminate(
      TerminateAmortizationPlanCommand(
        planId: prepaidId,
        terminatedAt: DateTime(2026, 2, 15),
        categoryReturnAllocations: const [
          AccountAmountAllocation(
            accountId: 'rent-expense',
            amount: Money(minorUnits: 33333),
          ),
          AccountAmountAllocation(
            accountId: 'utilities-expense',
            amount: Money(minorUnits: 16667),
          ),
        ],
        settlementAllocations: singleAllocation(
          accountId: 'fund',
          amount: Money(minorUnits: 50000),
        ),
      ),
    );
    expect(await fixture.balance('prepaid'), _money(0));
    expect(await fixture.balance('fund'), _money(-50000));
    expect(await fixture.balance('fund-2'), _money(-200000));
    expect(await fixture.balance('rent-expense'), _money(166667));
    expect(await fixture.balance('utilities-expense'), _money(83333));

    await fixture.service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.deferredIncome,
        total: _money(300000),
        fundingAllocations: singleAllocation(
          accountId: 'fund',
          amount: _money(300000),
        ),
        deferralAccountId: 'deferred',
        recognitionAllocations: singleAllocation(
          accountId: 'rent-income',
          amount: _money(300000),
        ),
        firstRecognitionAt: DateTime(2026, 3, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 3, 1),
      ),
    );
    await fixture.service.generateDue(DateTime(2026, 3, 31));

    expect(await fixture.balance('fund'), _money(250000));
    expect(await fixture.balance('deferred'), _money(200000));
    expect(await fixture.balance('rent-income'), _money(100000));

    final backupDirectory = await Directory.systemTemp.createTemp(
      'smartflow_amortization_backup_',
    );
    addTearDown(() => backupDirectory.delete(recursive: true));
    final backup = BackupService(
      gateway: DriftBackupGateway(fixture.database),
      packageStore: const FileBackupPackageStore(),
    );
    final manifest = await backup.createBackup(backupDirectory);
    final inspection = await backup.inspect(backupDirectory);
    expect(manifest.backupSchemaVersion, 7);
    expect(inspection.snapshot.rows('amortization_periods'), isNotEmpty);
    expect(inspection.snapshot.rows('amortization_allocations'), isNotEmpty);
  });

  test(
    'ledger failure rolls back the initial transfer and plan write',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final service = AmortizationPlanAppServiceImpl(
        repository: fixture.repository,
        ledger: _FailingAfterTransferLedger(fixture.ledger),
        transactionRunner: fixture.runner,
        idGenerator: fixture.ids,
      );

      await expectLater(
        service.createPlan(_command()),
        throwsA(isA<StateError>()),
      );

      expect(
        await fixture.database.select(fixture.database.amortizationPlans).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.transactions).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.entries).get(),
        isEmpty,
      );
      expect(await fixture.balance('fund'), Money.zero());
    },
  );

  test('outer failure after save rolls back ledger and plan writes', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final service = AmortizationPlanAppServiceImpl(
      repository: _FailAfterSaveRepository(fixture.database),
      ledger: fixture.ledger,
      transactionRunner: fixture.runner,
      idGenerator: fixture.ids,
    );

    await expectLater(
      service.createPlan(_command()),
      throwsA(isA<StateError>()),
    );

    expect(
      await fixture.database.select(fixture.database.amortizationPlans).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.transactions).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.entries).get(),
      isEmpty,
    );
    expect(await fixture.balance('fund'), Money.zero());
  });

  test('generateDue is idempotent under overlapping calls', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final planId = await fixture.service.createPlan(_command());

    final results = await Future.wait([
      fixture.service.generateDue(DateTime(2026, 4, 1)),
      fixture.service.generateDue(DateTime(2026, 4, 1)),
    ]);
    final firstCount = await _ownerTransactionCount(fixture.database, planId);
    final repeated = await fixture.service.generateDue(DateTime(2026, 4, 1));
    final secondCount = await _ownerTransactionCount(fixture.database, planId);

    expect(
      results.fold(0, (total, result) => total + result.generatedCount),
      3,
    );
    expect(firstCount, 4);
    expect(repeated.generatedCount, 0);
    expect(secondCount, firstCount);
  });

  test('failed refund edit restores transfer and period facts', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final planId = await fixture.service.createPlan(_command());
    await fixture.service.generateDue(DateTime(2026, 1, 31));
    await fixture.service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
        categoryAllocations: singleAllocation(
          accountId: 'rent-expense',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'fund',
          amount: _money(10000),
        ),
        occurredAt: DateTime(2026, 2, 1),
      ),
    );
    final before = (await fixture.repository.findById(planId))!;
    final balancesBefore = (
      fund: await fixture.balance('fund'),
      prepaid: await fixture.balance('prepaid'),
      expense: await fixture.balance('rent-expense'),
    );
    final service = AmortizationPlanAppServiceImpl(
      repository: _FailAfterSaveRepository(fixture.database),
      ledger: fixture.ledger,
      transactionRunner: fixture.runner,
      idGenerator: fixture.ids,
    );

    await expectLater(
      service.editRefund(
        EditAmortizationRefundCommand(
          planId: planId,
          refundId: before.refunds.single.id,
          categoryAllocations: singleAllocation(
            accountId: 'rent-expense',
            amount: _money(15000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'fund',
            amount: _money(15000),
          ),
          now: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final after = (await fixture.repository.findById(planId))!;
    expect(after.refundedAmount, before.refundedAmount);
    expect(
      after.periods.first.categoryAllocations
          .map((allocation) => (allocation.accountId, allocation.amount))
          .toList(),
      before.periods.first.categoryAllocations
          .map((allocation) => (allocation.accountId, allocation.amount))
          .toList(),
    );
    expect(await fixture.balance('fund'), balancesBefore.fund);
    expect(await fixture.balance('prepaid'), balancesBefore.prepaid);
    expect(await fixture.balance('rent-expense'), balancesBefore.expense);
  });

  test('failed undo restores termination and catch-up writes', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final planId = await fixture.service.createPlan(_command());
    await fixture.service.terminate(
      TerminateAmortizationPlanCommand(
        planId: planId,
        terminatedAt: DateTime(2026, 1, 31),
        categoryReturnAllocations: singleAllocation(
          accountId: 'rent-expense',
          amount: _money(5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'fund',
          amount: _money(5000),
        ),
      ),
    );
    final balancesBefore = (
      fund: await fixture.balance('fund'),
      prepaid: await fixture.balance('prepaid'),
      expense: await fixture.balance('rent-expense'),
    );
    final transactionCount = await _ownerTransactionCount(
      fixture.database,
      planId,
    );
    final service = AmortizationPlanAppServiceImpl(
      repository: _FailAfterSaveRepository(fixture.database),
      ledger: fixture.ledger,
      transactionRunner: fixture.runner,
      idGenerator: fixture.ids,
    );

    await expectLater(
      service.undoTermination(
        UndoAmortizationTerminationCommand(
          planId: planId,
          now: DateTime(2026, 4, 1),
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final plan = (await fixture.repository.findById(planId))!;
    expect(plan.status, AmortizationStatus.terminated);
    expect(
      await _ownerTransactionCount(fixture.database, planId),
      transactionCount,
    );
    expect(await fixture.balance('fund'), balancesBefore.fund);
    expect(await fixture.balance('prepaid'), balancesBefore.prepaid);
    expect(await fixture.balance('rent-expense'), balancesBefore.expense);
  });

  test(
    'failed plan delete restores transactions and projection rows',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final planId = await fixture.service.createPlan(_command());
      await fixture.service.generateDue(DateTime(2026, 1, 31));
      final transactionCount = await _ownerTransactionCount(
        fixture.database,
        planId,
      );
      final service = AmortizationPlanAppServiceImpl(
        repository: _FailAfterDeleteRepository(fixture.database),
        ledger: fixture.ledger,
        transactionRunner: fixture.runner,
        idGenerator: fixture.ids,
      );

      await expectLater(
        service.deletePlan(DeleteAmortizationPlanCommand(planId: planId)),
        throwsA(isA<StateError>()),
      );

      expect(await fixture.repository.findById(planId), isNotNull);
      expect(
        await _ownerTransactionCount(fixture.database, planId),
        transactionCount,
      );
    },
  );

  test('editing a refund rewrites current balances', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final planId = await fixture.service.createPlan(_command());
    await fixture.service.generateDue(DateTime(2026, 1, 31));
    await fixture.service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
        categoryAllocations: singleAllocation(
          accountId: 'rent-expense',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'fund',
          amount: _money(10000),
        ),
        occurredAt: DateTime(2026, 2, 1),
      ),
    );
    final plan = (await fixture.repository.findById(planId))!;

    await fixture.service.editRefund(
      EditAmortizationRefundCommand(
        planId: planId,
        refundId: plan.refunds.single.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent-expense',
          amount: _money(15000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'fund',
          amount: _money(15000),
        ),
        now: DateTime(2026, 2, 1),
      ),
    );

    expect(await fixture.balance('fund'), _money(-15000));
    expect(await fixture.balance('prepaid'), _money(10000));
    expect(await fixture.balance('rent-expense'), _money(5000));
  });

  test(
    'deleting a plan removes every projection and owner transaction',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final planId = await fixture.service.createPlan(_command());
      await fixture.service.generateDue(DateTime(2026, 1, 31));

      await fixture.service.deletePlan(
        DeleteAmortizationPlanCommand(planId: planId),
      );

      expect(await fixture.repository.findById(planId), isNull);
      expect(await _ownerTransactionCount(fixture.database, planId), 0);
      expect(
        await fixture.database
            .select(fixture.database.amortizationPeriods)
            .get(),
        isEmpty,
      );
      expect(
        await fixture.database
            .select(fixture.database.amortizationAllocations)
            .get(),
        isEmpty,
      );
    },
  );
}

CreateAmortizationPlanCommand _command() {
  return CreateAmortizationPlanCommand(
    kind: AmortizationKind.prepaidExpense,
    total: _money(30000),
    fundingAllocations: singleAllocation(
      accountId: 'fund',
      amount: _money(30000),
    ),
    deferralAccountId: 'prepaid',
    recognitionAllocations: singleAllocation(
      accountId: 'rent-expense',
      amount: _money(30000),
    ),
    firstRecognitionAt: DateTime(2026, 1, 31),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    recognitionCount: 3,
    occurredAt: DateTime(2026, 1, 1),
  );
}

Future<int> _ownerTransactionCount(AppDatabase database, String planId) async {
  final rows = await (database.select(
    database.transactions,
  )..where((table) => table.ownerId.equals(planId))).get();
  return rows.length;
}

final class _FailingAfterTransferLedger implements AmortizationLedgerPort {
  _FailingAfterTransferLedger(this.delegate);

  final AmortizationLedgerPort delegate;

  @override
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required Iterable<String> categoryAccountIds,
  }) {
    return delegate.validatePlanAccounts(
      kind: kind,
      deferralAccountId: deferralAccountId,
      categoryAccountIds: categoryAccountIds,
    );
  }

  @override
  Future<String> postTransfer({
    required Money amount,
    required List<AccountAmountAllocation> outgoingAllocations,
    required List<AccountAmountAllocation> incomingAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    Money? feeAmount,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) async {
    await delegate.postTransfer(
      amount: amount,
      outgoingAllocations: outgoingAllocations,
      incomingAllocations: incomingAllocations,
      occurredAt: occurredAt,
      postedAt: postedAt,
      feeAmount: feeAmount,
      counterpartyId: counterpartyId,
      note: note,
      ownership: ownership,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
      sourceKind: sourceKind,
      tagIds: tagIds,
    );
    throw StateError('Injected failure after ledger write.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _FailAfterSaveRepository extends DriftAmortizationRepository {
  const _FailAfterSaveRepository(super.database);

  @override
  Future<void> save(AmortizationPlan plan) async {
    await super.save(plan);
    throw StateError('Injected failure after repository write.');
  }
}

final class _FailAfterDeleteRepository extends DriftAmortizationRepository {
  const _FailAfterDeleteRepository(super.database);

  @override
  Future<void> deleteById(String id) async {
    await super.deleteById(id);
    throw StateError('Injected failure after repository delete.');
  }
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.accounts,
    required this.repository,
    required this.ledger,
    required this.runner,
    required this.ids,
    required this.service,
  });

  final AppDatabase database;
  final DriftAccountRepository accounts;
  final DriftAmortizationRepository repository;
  final LedgerAmortizationPort ledger;
  final DriftTransactionRunner runner;
  final SequentialIdGenerator ids;
  final AmortizationPlanAppServiceImpl service;

  static Future<_Fixture> create() async {
    final database = createTestDatabase();
    final accounts = DriftAccountRepository(database);
    for (final account in [
      _account('fund', AccountType.asset, AccountSubtype.fund, 'ledger.fund'),
      _account('fund-2', AccountType.asset, AccountSubtype.fund, 'ledger.fund'),
      _account(
        'prepaid',
        AccountType.asset,
        AccountSubtype.prepaidExpense,
        'ledger.prepaidExpense',
      ),
      _account(
        'deferred',
        AccountType.liability,
        AccountSubtype.deferredIncome,
        'ledger.deferredIncome',
      ),
      _category('rent-expense', AccountType.expense, '房租支出'),
      _category('utilities-expense', AccountType.expense, '水电支出'),
      _category('rent-income', AccountType.income, '房租收入'),
    ]) {
      await accounts.create(account);
    }

    final transactions = DriftPostingRepository(database);
    final runner = DriftTransactionRunner(database);
    final resolver = DriftSystemAccountResolver(database);
    final ids = SequentialIdGenerator(prefix: 'amortization');
    final writer = TransactionLedgerWriter(
      transactionRunner: runner,
      transactionRepository: transactions,
      transactionGroupRepository: transactions,
      accountRepository: accounts,
      transactionTagRepository: FakeTransactionTagRepository(),
      counterpartyRepository: FakeCounterpartyRepository(),
    );
    final posting = TransactionPostingAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: resolver,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    final editing = TransactionEditAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: transactions,
      systemAccountResolver: resolver,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    final ledger = LedgerAmortizationPort(
      posting: posting,
      editing: editing,
      accounts: accounts,
    );
    final repository = DriftAmortizationRepository(database);
    final service = AmortizationPlanAppServiceImpl(
      repository: repository,
      ledger: ledger,
      transactionRunner: runner,
      idGenerator: ids,
    );
    return _Fixture._(
      database: database,
      accounts: accounts,
      repository: repository,
      ledger: ledger,
      runner: runner,
      ids: ids,
      service: service,
    );
  }

  Future<Money> balance(String accountId) async =>
      (await accounts.findById(accountId))!.balance;

  Future<void> close() => database.close();
}

Account _account(
  String id,
  AccountType type,
  AccountSubtype subtype,
  String profileKey,
) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    profileKey: profileKey,
    balance: Money.zero(),
  );
}

Account _category(String id, AccountType type, String name) {
  return Account(id: id, name: name, type: type, balance: Money.zero());
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);
