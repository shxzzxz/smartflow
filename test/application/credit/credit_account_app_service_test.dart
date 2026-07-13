import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_account_port.dart';
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
      expect(await fixture.accountRepository.findById('account-1'), isNull);
      expect(
        await fixture.creditRepository.findByAccountId('account-1'),
        isNull,
      );
    });

    test(
      'rolls back credit outer transaction when ledger inner call fails',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);

        await expectLater(
          () => fixture.service.createAccount(
            const CreateCreditLiabilityAccountCommand(
              name: '',
              kind: CreditLiabilityAccountKind.loan,
            ),
          ),
          throwsA(isA<AppException>()),
        );

        expect(await fixture.accountRepository.findById('account-1'), isNull);
        expect(
          await fixture.creditRepository.findByAccountId('account-1'),
          isNull,
        );
      },
    );

    test(
      'rolls back ledger inner success when credit outer write fails',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final service = fixture.serviceWithCreditRepository(
          _FailingInsertCreditAccountRepository(),
        );

        await expectLater(
          () => service.createAccount(
            const CreateCreditLiabilityAccountCommand(
              name: 'Rollback Loan',
              kind: CreditLiabilityAccountKind.loan,
            ),
          ),
          throwsA(isA<StateError>()),
        );

        expect(await fixture.accountRepository.findById('account-1'), isNull);
        expect(
          await fixture.creditRepository.findByAccountId('account-1'),
          isNull,
        );
      },
    );
  });
}

class _Fixture {
  _Fixture() {
    final postingService = LedgerPostingService(
      accountRepository: accountRepository,
      systemAccountResolver: DriftSystemAccountResolver(database),
      postingEngine: PostingEngine(idGenerator: ids),
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(
        accountRepository: accountRepository,
      ),
    );
    accountAppService = AccountAppServiceImpl(
      accountRepository,
      transactionRunner: runner,
      ledgerPostingService: postingService,
      transactionRepository: DriftPostingRepository(database),
      idGenerator: ids,
    );
    service = CreditAccountAppServiceImpl(
      ledger: ledger,
      creditAccounts: creditRepository,
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  final database = createTestDatabase();
  final ids = SequentialIdGenerator(prefix: 'account');
  late final DriftTransactionRunner runner = DriftTransactionRunner(database);
  late final DriftAccountRepository accountRepository = DriftAccountRepository(
    database,
  );
  late final DriftCreditAccountRepository creditRepository =
      DriftCreditAccountRepository(database);
  late final AccountAppService accountAppService;
  late final LedgerCreditAccountPort ledger = LedgerCreditAccountPort(
    accountAppService,
  );
  late final CreditAccountAppService service;

  CreditAccountAppService serviceWithCreditRepository(
    CreditAccountRepository repository,
  ) {
    return CreditAccountAppServiceImpl(
      ledger: ledger,
      creditAccounts: repository,
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  Future<void> close() => database.close();
}

class _FailingInsertCreditAccountRepository implements CreditAccountRepository {
  @override
  Future<void> insert(CreditLiabilityAccountDraft draft) {
    throw StateError('credit extension insert failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
