import '../../../core/patch/patch.dart';
import '../entity/account.dart';
import '../entity/transaction.dart';
import '../valobj/transaction_ownership.dart';
import '../valobj/ledger_enum.dart';
import '../ledger/post_receipt.dart';

/// 账务核心的写入端口。
///
/// repository 只保存已经由领域对象决定好的聚合状态:
/// - [Transaction] 聚合负责交易 header/details/entries 的合法性。
/// - [Account] 聚合负责余额变化。
/// - repository 不接收外部 balance delta,也不解释借贷余额规则。
abstract interface class PostingRepository {
  Future<List<Account>> findAccountsByIds(Set<int> ids);

  Future<PostReceiptResult> saveTransaction(Transaction transaction);

  Future<void> saveAccounts(Iterable<Account> accounts);

  Future<void> updateTransactionState({
    required int transactionId,
    required BusinessState businessState,
  });

  Future<void> updateTransactionMetadata({
    required int transactionId,
    Patch<String>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  });

  Future<void> updateTransactionOwnership({
    required int transactionId,
    required TransactionOwnership ownership,
  });

  Future<void> updateTransactionBasics({
    required int transactionId,
    DateTime? occurredAt,
    List<EntryAccountReassignment> entryAccountReassignments = const [],
    List<Account> updatedAccounts = const [],
  });
}
