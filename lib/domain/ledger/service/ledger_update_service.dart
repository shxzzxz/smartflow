import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../entity/account.dart';
import '../entity/entry.dart';
import '../entity/root_transaction_group.dart';
import '../entity/transaction.dart';
import '../port/account_repository.dart';
import '../port/root_transaction_group_repository.dart';
import '../port/transaction_repository.dart';
import '../valobj/account_usage.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/posting_instruction.dart';
import '../valobj/posting_result.dart';
import 'account_role_policy.dart';
import 'entry_reassignment_service.dart';

class LedgerUpdateService {
  const LedgerUpdateService({
    required TransactionRepository transactionRepository,
    required RootTransactionGroupRepository rootGroupRepository,
    required AccountRepository accountRepository,
    required AccountRolePolicy accountRolePolicy,
    EntryReassignmentService reassignmentService =
        const EntryReassignmentService(),
  }) : _transactionRepository = transactionRepository,
       _rootGroupRepository = rootGroupRepository,
       _accountRepository = accountRepository,
       _accountRolePolicy = accountRolePolicy,
       _reassignmentService = reassignmentService;

  final TransactionRepository _transactionRepository;
  final RootTransactionGroupRepository _rootGroupRepository;
  final AccountRepository _accountRepository;
  final AccountRolePolicy _accountRolePolicy;
  final EntryReassignmentService _reassignmentService;

  Future<Result<TransactionUpdateResult>> updateMetadata(
    UpdateTransactionMetadataInstruction instruction,
  ) async {
    if (instruction.note == null &&
        instruction.isExcludedFromStats == null &&
        instruction.isExcludedFromBudget == null) {
      return _empty();
    }
    final transaction = await _transactionRepository.findCompleteById(
      instruction.transactionId,
    );
    if (transaction == null) return _failure('transaction_not_found');
    return Result.success(
      TransactionUpdateResult(
        transactions: [
          transaction.updatedMetadata(
            note: instruction.note,
            isExcludedFromStats: instruction.isExcludedFromStats,
            isExcludedFromBudget: instruction.isExcludedFromBudget,
          ),
        ],
        accounts: const [],
      ),
    );
  }

  Future<Result<TransactionUpdateResult>> updateOwnership(
    UpdateTransactionOwnershipInstruction instruction,
  ) async {
    final transaction = await _transactionRepository.findCompleteById(
      instruction.transactionId,
    );
    if (transaction == null) return _failure('transaction_not_found');
    return Result.success(
      TransactionUpdateResult(
        transactions: [transaction.updatedOwnership(instruction.ownership)],
        accounts: const [],
      ),
    );
  }

  Future<Result<TransactionUpdateResult>> updateBasics(
    UpdateTransactionBasicsInstruction instruction,
  ) async {
    if (instruction.occurredAt == null &&
        instruction.settlementAccountId == null &&
        instruction.reimbursementAccountId == null) {
      return _empty();
    }

    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final target = group.findTransaction(instruction.transactionId);
    if (target == null) return _failure('transaction_not_found');
    final updateFailure = target.assertCanBeBasicsUpdated();
    if (updateFailure != null) return Result.failure(updateFailure);

    final accountTypes = await _loadAccountTypes(
      target.entries.map((entry) => entry.accountId),
    );
    final reassignments = <EntryAccountReassignment>[];
    final settlementAccountId = instruction.settlementAccountId;
    if (settlementAccountId != null) {
      final reassignmentResult = await _settlementReassignment(
        target: target,
        accountTypes: accountTypes,
        settlementAccountId: settlementAccountId,
      );
      if (reassignmentResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      final reassignment = reassignmentResult.value;
      if (reassignment != null) reassignments.add(reassignment);
    }

    final reimbursementAccountId = instruction.reimbursementAccountId;
    if (reimbursementAccountId != null) {
      final reassignmentResult = await _reimbursementReassignment(
        target: target,
        accountTypes: accountTypes,
        reimbursementAccountId: reimbursementAccountId,
      );
      if (reassignmentResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      final reassignment = reassignmentResult.value;
      if (reassignment != null) reassignments.add(reassignment);
    }

    final scopes = _scopesFor(group);
    final accounts = await _loadAccountsFor(reassignments);
    final changedAccounts = _reassignmentService
        .recomputeAccountsForReassignments(
          accounts: accounts,
          scopes: scopes,
          reassignments: reassignments,
        );
    final changedTransactions = _applyBasics(
      group: group,
      targetId: target.id,
      occurredAt: instruction.occurredAt,
      reassignments: reassignments,
    );
    return Result.success(
      TransactionUpdateResult(
        transactions: changedTransactions,
        accounts: changedAccounts,
      ),
    );
  }

  Future<Result<EntryAccountReassignment?>> _settlementReassignment({
    required Transaction target,
    required Map<String, AccountType> accountTypes,
    required String settlementAccountId,
  }) async {
    final entry = _reassignmentService.findSettlementEntry(
      businessPurpose: target.businessPurpose,
      entries: target.entries,
      accountTypes: accountTypes,
    );
    if (entry == null) return _failure('settlement_account_not_found');
    final failure = await _accountRolePolicy.validate(
      AccountRoleContext([
        AccountRoleRequirement(
          accountId: settlementAccountId,
          expectedTypes: {AccountType.asset, AccountType.liability},
          requiredUsage: AccountUsage.settlement,
          allowReimbursementSubtype: false,
        ),
      ]),
    );
    if (failure != null) return Result.failure(failure);
    if (entry.accountId == settlementAccountId) {
      return const Result.success(null);
    }
    return Result.success(
      EntryAccountReassignment(
        transactionId: target.id,
        fromAccountId: entry.accountId,
        toAccountId: settlementAccountId,
      ),
    );
  }

  Future<Result<EntryAccountReassignment?>> _reimbursementReassignment({
    required Transaction target,
    required Map<String, AccountType> accountTypes,
    required String reimbursementAccountId,
  }) async {
    if (target.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_account_unsupported',
          message:
              'Only reimbursement advances can change reimbursement account.',
        ),
      );
    }
    final entry = _reassignmentService.findReimbursementReceivableEntry(
      entries: target.entries,
      accountTypes: accountTypes,
    );
    if (entry == null) return _failure('reimbursement_account_not_found');
    final failure = await _accountRolePolicy.validate(
      AccountRoleContext([
        AccountRoleRequirement(
          accountId: reimbursementAccountId,
          expectedTypes: {AccountType.asset},
          requiredSubtype: AccountSubtype.reimbursement,
        ),
      ]),
    );
    if (failure != null) return Result.failure(failure);
    if (entry.accountId == reimbursementAccountId) {
      return const Result.success(null);
    }
    return Result.success(
      EntryAccountReassignment(
        rootTransactionId: target.rootTransactionId,
        fromAccountId: entry.accountId,
        toAccountId: reimbursementAccountId,
      ),
    );
  }

  List<Transaction> _applyBasics({
    required RootTransactionGroup group,
    required String targetId,
    required DateTime? occurredAt,
    required List<EntryAccountReassignment> reassignments,
  }) {
    final changed = <String, Transaction>{};
    for (final transaction in group.transactions) {
      var next = transaction;
      if (transaction.id == targetId && occurredAt != null) {
        next = next.withOccurredAt(occurredAt);
      }
      final nextEntries = _reassignedEntries(next, reassignments);
      if (nextEntries != null) {
        next = next.copyWith(entries: nextEntries);
      }
      if (!identical(next, transaction)) {
        changed[next.id] = next;
      }
    }
    return changed.values.toList();
  }

  List<Entry>? _reassignedEntries(
    Transaction transaction,
    List<EntryAccountReassignment> reassignments,
  ) {
    var changed = false;
    final entries = [
      for (final entry in transaction.entries)
        _reassignedEntry(
          transaction: transaction,
          entry: entry,
          reassignments: reassignments,
          markChanged: () => changed = true,
        ),
    ];
    return changed ? entries : null;
  }

  Entry _reassignedEntry({
    required Transaction transaction,
    required Entry entry,
    required List<EntryAccountReassignment> reassignments,
    required void Function() markChanged,
  }) {
    var accountId = entry.accountId;
    for (final reassignment in reassignments) {
      final inScope =
          reassignment.transactionId == transaction.id ||
          reassignment.rootTransactionId == transaction.rootTransactionId;
      if (inScope && accountId == reassignment.fromAccountId) {
        accountId = reassignment.toAccountId;
        markChanged();
      }
    }
    if (accountId == entry.accountId) return entry;
    return Entry(
      id: entry.id,
      transactionId: entry.transactionId,
      accountId: accountId,
      direction: entry.direction,
      amount: entry.amount,
    );
  }

  List<EntryReassignmentScope> _scopesFor(RootTransactionGroup group) {
    return [
      for (final transaction in group.transactions)
        EntryReassignmentScope(
          transactionId: transaction.id,
          rootTransactionId: transaction.rootTransactionId,
          businessState: transaction.businessState,
          entries: transaction.entries,
        ),
    ];
  }

  Future<Map<String, AccountType>> _loadAccountTypes(
    Iterable<String> accountIds,
  ) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await _accountRepository.findByIds(ids);
    return {for (final account in accounts) account.id: account.type};
  }

  Future<Map<String, Account>> _loadAccountsFor(
    List<EntryAccountReassignment> reassignments,
  ) async {
    if (reassignments.isEmpty) return const {};
    final accountIds = <String>{
      for (final reassignment in reassignments) reassignment.fromAccountId,
      for (final reassignment in reassignments) reassignment.toAccountId,
    };
    final accounts = await _accountRepository.findByIds(accountIds);
    return {for (final account in accounts) account.id: account};
  }

  Result<TransactionUpdateResult> _empty() {
    return const Result.success(
      TransactionUpdateResult(transactions: [], accounts: []),
    );
  }

  Result<T> _failure<T>(String code) {
    return Result.failure(
      Failure(code: code, message: 'Ledger update failed: $code.'),
    );
  }
}
