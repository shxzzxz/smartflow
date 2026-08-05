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
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_generation_suppression_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
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

    test(
      'deletes an archived credit account and its empty projections',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final account = await fixture.service.createAccount(
          const CreateCreditLiabilityAccountCommand(
            name: 'Mistaken card',
            kind: CreditLiabilityAccountKind.credit,
            billingDay: 5,
            repaymentDay: 25,
          ),
        );
        final period = BillPeriod(year: 2026, month: 8);
        await fixture.billRepository.saveBill(
          Bill(
            id: 'empty-bill',
            accountId: account.id,
            period: period,
            status: BillStatus.open,
            items: const [],
          ),
        );
        await fixture.suppressionRepository.suppress(account.id, period);
        await fixture.accountAppService.archiveAccount(
          ArchiveAccountCommand(id: account.id),
        );

        await fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        );

        expect(await fixture.accountRepository.findById(account.id), isNull);
        expect(
          await fixture.creditRepository.findByAccountId(account.id),
          isNull,
        );
        expect(
          await fixture.billRepository.listBillsByAccount(account.id),
          isEmpty,
        );
        expect(
          await fixture.suppressionRepository.isSuppressed(account.id, period),
          isFalse,
        );
      },
    );

    test('rejects deleting a credit account with bill source items', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Used card',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
        ),
      );
      final bill = await fixture.billRepository.saveBill(
        Bill(
          id: 'used-bill',
          accountId: account.id,
          period: BillPeriod(year: 2026, month: 8),
          status: BillStatus.billed,
          items: const [],
        ),
      );
      await fixture.billRepository.replaceBillItems(bill.id, [
        BillItem(
          id: 'consumption',
          billId: bill.id,
          itemType: BillItemType.consumption,
          repaymentDate: DateTime(2026, 8, 25),
          expectedPrincipal: const Money(minorUnits: 1000),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
          status: BillItemStatus.pending,
        ),
      ]);
      await fixture.accountAppService.archiveAccount(
        ArchiveAccountCommand(id: account.id),
      );

      await expectLater(
        () => fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.accountInUse.code,
          ),
        ),
      );

      expect(await fixture.accountRepository.findById(account.id), isNotNull);
      expect(
        await fixture.creditRepository.findByAccountId(account.id),
        isNotNull,
      );
    });

    test('rejects deleting a credit account with a contract', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Card with contract',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
        ),
      );
      await fixture.installmentRepository.insertAggregate(
        _contract(account.id),
        const [],
      );
      await fixture.accountAppService.archiveAccount(
        ArchiveAccountCommand(id: account.id),
      );

      await expectLater(
        () => fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.accountInUse.code,
          ),
        ),
      );
    });

    test('rejects deleting a credit account with account repayment', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Card with repayment',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
        ),
      );
      await fixture.repaymentRepository.saveRepayment(
        _repayment(
          id: 'account-repayment',
          type: RepaymentType.unattributed,
          targetType: RepaymentTargetType.account,
          targetId: account.id,
          transactionId: 'ledger-transaction',
        ),
      );
      await fixture.accountAppService.archiveAccount(
        ArchiveAccountCommand(id: account.id),
      );

      await expectLater(
        () => fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.accountInUse.code,
          ),
        ),
      );
    });

    test('rejects deleting a credit account with bill repayment', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Card with bill repayment',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
        ),
      );
      final bill = await fixture.billRepository.saveBill(
        Bill(
          id: 'repaid-bill',
          accountId: account.id,
          period: BillPeriod(year: 2026, month: 8),
          status: BillStatus.billed,
          items: const [],
        ),
      );
      await fixture.repaymentRepository.saveRepayment(
        _repayment(
          id: 'bill-repayment',
          type: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: bill.id,
          billItemId: 'historical-bill-item',
        ),
      );
      await fixture.accountAppService.archiveAccount(
        ArchiveAccountCommand(id: account.id),
      );

      await expectLater(
        () => fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.accountInUse.code,
          ),
        ),
      );
    });

    test('rolls back credit cleanup when ledger deletion fails', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final account = await fixture.service.createAccount(
        const CreateCreditLiabilityAccountCommand(
          name: 'Active card',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
        ),
      );
      final period = BillPeriod(year: 2026, month: 8);
      await fixture.billRepository.saveBill(
        Bill(
          id: 'rollback-bill',
          accountId: account.id,
          period: period,
          status: BillStatus.open,
          items: const [],
        ),
      );
      await fixture.suppressionRepository.suppress(account.id, period);

      await expectLater(
        () => fixture.service.deleteAccount(
          DeleteCreditLiabilityAccountCommand(accountId: account.id),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            LedgerErrorCode.accountUnavailable.code,
          ),
        ),
      );

      expect(
        await fixture.creditRepository.findByAccountId(account.id),
        isNotNull,
      );
      expect(
        await fixture.billRepository.listBillsByAccount(account.id),
        hasLength(1),
      );
      expect(
        await fixture.suppressionRepository.isSuppressed(account.id, period),
        isTrue,
      );
    });
  });
}

InstallmentContract _contract(String accountId) {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: accountId,
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 1000),
    totalPeriods: 1,
    borrowingDate: DateTime(2026, 7, 1),
    firstRepaymentDate: DateTime(2026, 8, 1),
    lastRepaymentDate: DateTime(2026, 8, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 7, 1),
  );
}

Repayment _repayment({
  required String id,
  required RepaymentType type,
  required RepaymentTargetType targetType,
  required String targetId,
  String? transactionId,
  String? billItemId,
}) {
  return Repayment(
    id: id,
    repaymentType: type,
    targetType: targetType,
    targetId: targetId,
    transactionId: transactionId,
    items: [
      RepaymentItem(
        id: '$id-item',
        repaymentId: id,
        billItemId: billItemId,
        allocated: const RepaymentAmountBreakdown(
          principal: Money(minorUnits: 1),
          interest: Money(minorUnits: 0),
          fee: Money(minorUnits: 0),
          discount: Money(minorUnits: 0),
        ),
      ),
    ],
  );
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
      bills: billRepository,
      installments: installmentRepository,
      repayments: repaymentRepository,
      suppressions: suppressionRepository,
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
  late final DriftBillRepository billRepository = DriftBillRepository(database);
  late final DriftInstallmentRepository installmentRepository =
      DriftInstallmentRepository(database);
  late final DriftRepaymentRepository repaymentRepository =
      DriftRepaymentRepository(database);
  late final DriftBillGenerationSuppressionRepository suppressionRepository =
      DriftBillGenerationSuppressionRepository(database);
  late final AccountAppServiceImpl accountAppService;
  late final LedgerCreditAccountPort ledger = LedgerCreditAccountPort(
    accountAppService,
    accountDeletion: accountAppService,
  );
  late final CreditAccountAppService service;

  CreditAccountAppService serviceWithCreditRepository(
    CreditAccountRepository repository,
  ) {
    return CreditAccountAppServiceImpl(
      ledger: ledger,
      creditAccounts: repository,
      bills: billRepository,
      installments: installmentRepository,
      repayments: repaymentRepository,
      suppressions: suppressionRepository,
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
