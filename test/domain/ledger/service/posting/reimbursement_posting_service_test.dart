import 'package:test/test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/reimbursement_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  test(
    'receipt cannot exceed reimbursement outstanding after refunds',
    () async {
      final fixture = _Fixture();

      await expectLater(
        () => fixture.service.postReceipt(
          ReimbursementReceiptInstruction(
            advanceTransactionId: fixture.advance.id,
            amount: Money.parse('40.01'),
            receivableAccountId: 'receivable',
            receiveAccountId: 'cash',
            occurredAt: DateTime(2026, 7, 3),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('close settles only the outstanding left after refunds', () async {
    final fixture = _Fixture(refundAmount: Money.parse('20.00'));

    final result = await fixture.service.close(
      ReimbursementCloseInstruction(
        advanceTransactionId: fixture.advance.id,
        actualReceivedAmount: Money.parse('80.00'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'cash',
        occurredAt: DateTime(2026, 7, 3),
      ),
    );

    expect(
      result.transaction.details
          .singleWhere(
            (detail) =>
                detail.type == TransactionDetailType.reimbursementCloseMain,
          )
          .amount,
      Money.parse('80.00'),
    );
    expect(
      result.transaction.details.where(
        (detail) =>
            detail.type == TransactionDetailType.reimbursementGapExpense ||
            detail.type == TransactionDetailType.reimbursementGapIncome,
      ),
      isEmpty,
    );
    expect(
      result.transaction.entries
          .singleWhere(
            (entry) =>
                entry.accountId == 'receivable' &&
                entry.direction == EntryDirection.credit,
          )
          .amount,
      Money.parse('80.00'),
    );
  });
}

class _Fixture {
  _Fixture({Money? refundAmount}) {
    advance = engine.createReimbursementAdvance(
      ReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: advance.id,
        amount: refundAmount ?? Money.parse('60.00'),
        refundToAccountId: 'cash',
        occurredAt: DateTime(2026, 7, 2),
      ),
      parent: advance,
      refundOffsetAccountId: 'receivable',
    );
    final accountRepository = _AccountRepository([
      _account('cash', AccountType.asset),
      _account(
        'receivable',
        AccountType.asset,
        subtype: AccountSubtype.reimbursement,
      ),
      _account('travel', AccountType.expense),
    ]);
    service = ReimbursementPostingService(
      transactionGroupRepository: _TransactionGroupRepository(
        TransactionGroup(
          parentTransaction: advance,
          childTransactions: [refund],
        ),
      ),
      accountRepository: accountRepository,
      systemAccountResolver: const _SystemAccountResolver(),
      postingEngine: engine,
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(
        accountRepository: accountRepository,
      ),
    );
  }

  final PostingEngine engine = PostingEngine(
    idGenerator: SequentialIdGenerator(prefix: 'tx'),
  );
  late final Transaction advance;
  late final ReimbursementPostingService service;
}

Account _account(String id, AccountType type, {AccountSubtype? subtype}) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}

class _TransactionGroupRepository implements TransactionGroupRepository {
  const _TransactionGroupRepository(this.group);

  final TransactionGroup group;

  @override
  Future<TransactionGroup?> findByParentId(String parentTransactionId) async =>
      group;

  @override
  Future<TransactionGroup?> findByTransactionId(String transactionId) async =>
      group;

  @override
  Future<void> applyRewrite(TransactionGroupRewritePlan plan) async {}

  @override
  Future<void> deleteChild(String childTransactionId) async {}

  @override
  Future<void> deleteGroup(String parentTransactionId) async {}
}

class _AccountRepository implements AccountRepository {
  _AccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  @override
  Future<void> create(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<Account?> findById(String id) async => _accounts[id];

  @override
  Future<List<Account>> findByIds(Set<String> ids) async => [
    for (final id in ids)
      if (_accounts[id] case final account?) account,
  ];

  @override
  Future<List<Account>> findChildrenOf(String parentId) async => const [];

  @override
  Future<void> save(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    for (final account in accounts) {
      _accounts[account.id] = account;
    }
  }
}

class _SystemAccountResolver implements SystemAccountResolver {
  const _SystemAccountResolver();

  @override
  Future<String> resolveDiscountIncome() => throw UnimplementedError();

  @override
  Future<String> resolveFeeExpense() => throw UnimplementedError();

  @override
  Future<String> resolveGhostAccount() => throw UnimplementedError();

  @override
  Future<String> resolveInterestExpense() => throw UnimplementedError();

  @override
  Future<String> resolveOpeningBalance() => throw UnimplementedError();

  @override
  Future<String> resolveReimbursementGapIncome() => throw UnimplementedError();
}
