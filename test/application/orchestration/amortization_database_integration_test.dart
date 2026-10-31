import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_update_app_service.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
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
        fundingAccountId: 'fund',
        deferralAccountId: 'prepaid',
        categoryAccountId: 'rent-expense',
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await fixture.service.generateDue(DateTime(2026, 1, 31));

    expect(await fixture.balance('fund'), _money(-300000));
    expect(await fixture.balance('prepaid'), _money(200000));
    expect(await fixture.balance('rent-expense'), _money(100000));

    await fixture.service.terminate(
      TerminateAmortizationPlanCommand(
        planId: prepaidId,
        terminatedAt: DateTime(2026, 2, 15),
        refundAccountId: 'fund',
        refundAmount: _money(50000),
      ),
    );
    expect(await fixture.balance('prepaid'), _money(0));
    expect(await fixture.balance('fund'), _money(-250000));
    expect(await fixture.balance('rent-expense'), _money(250000));

    await fixture.service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.deferredIncome,
        total: _money(300000),
        fundingAccountId: 'fund',
        deferralAccountId: 'deferred',
        categoryAccountId: 'rent-income',
        firstRecognitionAt: DateTime(2026, 3, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 3, 1),
      ),
    );
    await fixture.service.generateDue(DateTime(2026, 3, 31));

    expect(await fixture.balance('fund'), _money(50000));
    expect(await fixture.balance('deferred'), _money(200000));
    expect(await fixture.balance('rent-income'), _money(100000));
  });
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.accounts,
    required this.service,
  });

  final AppDatabase database;
  final DriftAccountRepository accounts;
  final AmortizationPlanAppServiceImpl service;

  static Future<_Fixture> create() async {
    final database = createTestDatabase();
    final accounts = DriftAccountRepository(database);
    for (final account in [
      _account('fund', AccountType.asset, AccountSubtype.fund, 'ledger.fund'),
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
    final updating = TransactionUpdateAppServiceImpl(
      transactionRepository: transactions,
      transactionGroupRepository: transactions,
      ledgerWriter: writer,
    );
    final ledger = LedgerAmortizationPort(
      posting: posting,
      editing: editing,
      updating: updating,
      accounts: accounts,
      transactions: transactions,
    );
    final service = AmortizationPlanAppServiceImpl(
      repository: DriftAmortizationRepository(database),
      ledger: ledger,
      transactionRunner: runner,
      idGenerator: ids,
    );
    return _Fixture._(database: database, accounts: accounts, service: service);
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
