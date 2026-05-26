import '../entity/account.dart';
import '../entity/transaction.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/post_receipt.dart';

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

  /// 按 [Transaction] 聚合当前状态整行 update(WHERE id = transaction.id)。
  /// caller(application 用例)先 load → 实体行为 → 调用本方法保存。
  Future<void> updateTransaction(Transaction transaction);

  /// 把一条 entry 的 accountId 从 [EntryAccountReassignment.fromAccountId]
  /// 改到 toAccountId;受影响 account 的余额由 caller 另行通过 [saveAccounts]
  /// 写回。
  Future<void> reassignEntryAccount(EntryAccountReassignment reassignment);
}
