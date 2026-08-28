import '../../entity/account.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_result.dart';
import 'account_posting_service.dart';

/// Loads the accounts referenced by a posted transaction, validates that they
/// are usable, and applies the transaction's entry impacts.
///
/// Posting services remain responsible for their business-specific checks and
/// transaction construction. This service owns the common account boundary
/// that follows construction and precedes persistence.
class PostingApplicationService {
  const PostingApplicationService({
    required AccountRepository accountRepository,
    required AccountPostingService accountPostingService,
  }) : _accountRepository = accountRepository,
       _accountPostingService = accountPostingService;

  final AccountRepository _accountRepository;
  final AccountPostingService _accountPostingService;

  Future<PostingResult> apply(
    Transaction transaction, {
    Iterable<Account> loadedAccounts = const [],
  }) async {
    final accountMap = {
      for (final account in loadedAccounts) account.id: account,
    };
    final missingIds = transaction.accountIds.difference(
      accountMap.keys.toSet(),
    );
    if (missingIds.isNotEmpty) {
      final accounts = await _accountRepository.findByIds(missingIds);
      accountMap.addEntries(
        accounts.map((account) => MapEntry(account.id, account)),
      );
    }
    final accountViolation = _validateAccountsLoaded(
      transaction.accountIds,
      accountMap,
    );
    if (accountViolation != null) accountViolation.throwException();
    return PostingResult(
      transaction: transaction,
      accounts: _accountPostingService.apply(
        transaction: transaction,
        accounts: accountMap,
      ),
    );
  }

  LedgerViolationReason? _validateAccountsLoaded(
    Set<String> accountIds,
    Map<String, Account> accounts,
  ) {
    for (final accountId in accountIds) {
      final account = accounts[accountId];
      if (account == null) return LedgerViolationReason.accountNotFound;
      if (account.archivedAt != null) {
        return LedgerViolationReason.accountArchived;
      }
    }
    return null;
  }
}
