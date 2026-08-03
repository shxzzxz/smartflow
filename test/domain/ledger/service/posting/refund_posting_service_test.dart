import 'package:test/test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/refund_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  test(
    'refund cannot exceed reimbursement outstanding after receipts',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final advance = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: advance.id,
          amount: Money.parse('60.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'cash',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: advance,
      );
      final accountRepository = _AccountRepository([
        _account('cash', AccountType.asset),
        _account(
          'receivable',
          AccountType.asset,
          subtype: AccountSubtype.reimbursement,
        ),
      ]);
      final service = RefundPostingService(
        transactionGroupRepository: _TransactionGroupRepository(
          TransactionGroup(
            parentTransaction: advance,
            childTransactions: [receipt],
          ),
        ),
        accountRepository: accountRepository,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        postingEngine: engine,
        accountPostingService: const DefaultAccountPostingService(),
        accountRolePolicy: AccountRolePolicy(
          accountRepository: accountRepository,
        ),
      );

      await expectLater(
        () => service.postRefund(
          RefundInstruction(
            parentTransactionId: advance.id,
            amount: Money.parse('40.01'),
            refundToAccountId: 'cash',
            occurredAt: DateTime(2026, 7, 3),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );
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
  Future<List<Account>> findByGroupId(String? groupId) async => [
    for (final account in _accounts.values)
      if (account.groupId == groupId) account,
  ];

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

  @override
  Future<void> delete(String id) async {
    _accounts.remove(id);
  }
}
