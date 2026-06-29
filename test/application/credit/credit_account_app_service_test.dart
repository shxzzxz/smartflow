import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('CreditAccountAppService', () {
    test(
      'creates credit account with billing parameters in credit extension',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);

        final account = await fixture.service.createAccount(
          const CreateCreditLiabilityAccountCommand(
            name: 'Huabei',
            kind: CreditLiabilityAccountKind.credit,
            creditLimit: Money(minorUnits: 100000),
            billingDay: 5,
            repaymentDay: 25,
          ),
        );

        final ledgerAccount = await fixture.accountRepository.findById(
          account.id,
        );
        final creditAccount = await fixture.creditRepository.findByAccountId(
          account.id,
        );
        expect(ledgerAccount!.profileKey, 'credit.credit');
        expect(ledgerAccount.balance, Money.zero());
        expect(creditAccount!.kind, CreditLiabilityAccountKind.credit);
        expect(creditAccount.creditLimit, const Money(minorUnits: 100000));
        expect(creditAccount.billingDay, 5);
        expect(creditAccount.repaymentDay, 25);
        expect(creditAccount.billingStartPeriod, BillPeriod.fromInt(202606));
        expect(creditAccount.billingDayToNext, true);
        expect(account.id, 'account-1');
        expect(ledgerAccount.id, creditAccount.accountId);
        expect(creditAccount.id, 'account-2');
      },
    );

    test('creates loan account without cycle parameters', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);

      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Jiebei',
          kind: CreditLiabilityAccountKind.loan,
          creditLimit: Money(minorUnits: 300000),
        ),
      );

      final ledgerAccount = await fixture.accountRepository.findById(
        account.id,
      );
      final creditAccount = await fixture.creditRepository.findByAccountId(
        account.id,
      );
      expect(ledgerAccount!.profileKey, 'credit.loan');
      expect(creditAccount!.kind, CreditLiabilityAccountKind.loan);
      expect(creditAccount.creditLimit, const Money(minorUnits: 300000));
      expect(creditAccount.billingDay, isNull);
      expect(creditAccount.repaymentDay, isNull);
      expect(creditAccount.billingStartPeriod, isNull);
    });

    test(
      'edits credit limit with Patch clear without touching cycle',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.service.createAccount(
          const CreateCreditLiabilityAccountCommand(
            name: 'Card',
            kind: CreditLiabilityAccountKind.credit,
            creditLimit: Money(minorUnits: 100000),
            billingDay: 5,
            repaymentDay: 25,
          ),
        );

        await fixture.service.editAccount(
          EditCreditLiabilityAccountCommand(
            accountId: account.id,
            name: 'Card Updated',
            creditLimit: const Patch<Money>.clear(),
          ),
        );

        final ledgerAccount = await fixture.accountRepository.findById(
          account.id,
        );
        final creditAccount = await fixture.creditRepository.findByAccountId(
          account.id,
        );
        expect(ledgerAccount!.name, 'Card Updated');
        expect(creditAccount!.creditLimit, isNull);
        expect(creditAccount.billingDay, 5);
        expect(creditAccount.repaymentDay, 25);
      },
    );

    test('rejects invalid credit cycle parameters', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);

      await expectLater(
        () => fixture.service.createAccount(
          const CreateCreditLiabilityAccountCommand(
            name: 'Invalid Card',
            kind: CreditLiabilityAccountKind.credit,
            billingDay: 29,
            repaymentDay: 25,
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.accountInvalidCommand.code,
          ),
        ),
      );
    });
  });
}

class _Fixture {
  _Fixture() {
    final ids = SequentialIdGenerator(prefix: 'account');
    final runner = DriftTransactionRunner(database);
    final postingService = LedgerPostingService(
      accountRepository: accountRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      postingEngine: PostingEngine(idGenerator: ids),
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(
        accountRepository: accountRepository,
      ),
    );
    final accountAppService = AccountAppServiceImpl(
      accountRepository,
      transactionRunner: runner,
      ledgerPostingService: postingService,
      transactionRepository: DriftPostingRepository(database),
      idGenerator: ids,
    );
    service = CreditAccountAppServiceImpl(
      accountAppService: accountAppService,
      creditAccounts: creditRepository,
      transactionRunner: runner,
      idGenerator: ids,
      now: () => DateTime(2026, 6, 15),
    );
  }

  final database = createTestDatabase();
  late final DriftAccountRepository accountRepository = DriftAccountRepository(
    database,
  );
  late final DriftCreditAccountRepository creditRepository =
      DriftCreditAccountRepository(database);
  late final CreditAccountAppService service;

  Future<void> close() => database.close();
}
