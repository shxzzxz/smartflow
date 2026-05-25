import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../entities/account.dart';
import '../entities/transaction.dart';
import '../entities/transaction_fact.dart';
import '../enums/accounting_enums.dart';
import '../ports/posting_repository.dart';
import 'ledger_rules.dart';
import 'post_receipt.dart';

/// 账务核心的过账员:把 [PostReceipt] 校验后交由 [PostingRepository] 落库。
///
/// 三个入口对应三种业务路径:
/// - [create]:用户新建一笔交易。
/// - [replace]:用户更正一笔交易 — Poster 内部从 original 派生红字凭证、注入
///   correction 元数据,在单 db 事务内完成"original→replaced + 红字 + 新蓝字"。
/// - [cancel] / [cancelMany]:用户删除一笔(或一组)交易 — 对每笔 original 派生红字凭证,
///   置 canceled。
///
/// 调用方(service)只造"纯净蓝字" [PostReceipt],不知道也不应知道 mutation
/// 元数据怎么注入、reversal 怎么派生。
abstract interface class Poster {
  Future<Result<PostReceiptResult>> create(PostReceipt receipt);

  Future<Result<PostReceiptResult>> replace({
    required TransactionFact original,
    required PostReceipt newReceipt,
  });

  Future<Result<void>> cancel(TransactionFact original);

  Future<Result<void>> cancelMany({required List<TransactionFact> originals});
}

class PosterImpl implements Poster {
  const PosterImpl(this._repository);

  final PostingRepository _repository;

  @override
  Future<Result<PostReceiptResult>> create(PostReceipt receipt) async {
    try {
      final accounts = await _loadAccounts(receipt);
      final accountFailure = _validateAccounts(receipt, accounts);
      if (accountFailure != null) return Result.failure(accountFailure);
      final receiptFailure = _validateReceipt(
        receipt,
        allowNegativeAmounts: false,
      );
      if (receiptFailure != null) return Result.failure(receiptFailure);
      final transaction = Transaction.fromReceipt(receipt);
      final updatedAccounts = _applyTransactionsToAccounts(accounts, [
        transaction,
      ]);
      final result = await _repository.saveTransaction(transaction);
      await _repository.saveAccounts(updatedAccounts);
      return Result.success(result);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_failed',
          message: 'Failed to post transaction.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<PostReceiptResult>> replace({
    required TransactionFact original,
    required PostReceipt newReceipt,
  }) async {
    try {
      final correctionReceipt = _inheritFromOriginal(newReceipt, original);
      final reversalReceipt = _deriveReversal(original);

      final accounts = await _loadAccounts(correctionReceipt);
      final accountFailure = _validateAccounts(correctionReceipt, accounts);
      if (accountFailure != null) return Result.failure(accountFailure);

      final correctionFailure = _validateReceipt(
        correctionReceipt,
        allowNegativeAmounts: false,
      );
      if (correctionFailure != null) return Result.failure(correctionFailure);

      final reversalFailure = _validateReceipt(
        reversalReceipt,
        allowNegativeAmounts: true,
      );
      if (reversalFailure != null) return Result.failure(reversalFailure);

      final reversalTransaction = Transaction.fromReceipt(
        reversalReceipt,
        mutationKind: MutationKind.reversal,
        businessState: BusinessState.compensation,
        mutationReason: MutationReason.correction,
        mutationPreviousTransactionId: original.transaction.id,
        allowNegativeAmounts: true,
      );
      var accountsForWrite = Map<int, Account>.of(accounts);
      accountsForWrite.addAll(await _loadAccounts(reversalReceipt));
      final afterReversal = _applyTransactionsToAccounts(accountsForWrite, [
        reversalTransaction,
      ]);

      await _repository.updateTransactionState(
        transactionId: original.transaction.id,
        businessState: BusinessState.replaced,
      );
      final reversalResult = await _repository.saveTransaction(
        reversalTransaction,
      );

      final correctionTransaction = Transaction.fromReceipt(
        correctionReceipt,
        mutationKind: MutationKind.correction,
        businessState: BusinessState.current,
        mutationPreviousTransactionId: reversalResult.transactionId,
      );
      final afterCorrection = _applyTransactionsToAccounts(
        {for (final account in afterReversal) account.id: account},
        [correctionTransaction],
      );
      final result = await _repository.saveTransaction(correctionTransaction);
      await _repository.saveAccounts(afterCorrection);
      return Result.success(result);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_mutation_failed',
          message: 'Failed to mutate transactions.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> cancel(TransactionFact original) =>
      cancelMany(originals: [original]);

  @override
  Future<Result<void>> cancelMany({
    required List<TransactionFact> originals,
  }) async {
    try {
      final reversalTransactions = <Transaction>[];
      final accountMap = <int, Account>{};
      for (final original in originals) {
        final reversal = _deriveReversal(original);
        final reversalFailure = _validateReceipt(
          reversal,
          allowNegativeAmounts: true,
        );
        if (reversalFailure != null) return Result.failure(reversalFailure);
        final accounts = await _loadAccounts(reversal);
        accountMap.addAll(accounts);
        reversalTransactions.add(
          Transaction.fromReceipt(
            reversal,
            mutationKind: MutationKind.reversal,
            businessState: BusinessState.compensation,
            mutationReason: MutationReason.delete,
            mutationPreviousTransactionId: original.transaction.id,
            allowNegativeAmounts: true,
          ),
        );
      }
      final updatedAccounts = _applyTransactionsToAccounts(
        accountMap,
        reversalTransactions,
      );
      for (var i = 0; i < originals.length; i++) {
        await _repository.updateTransactionState(
          transactionId: originals[i].transaction.id,
          businessState: BusinessState.canceled,
        );
        await _repository.saveTransaction(reversalTransactions[i]);
      }
      await _repository.saveAccounts(updatedAccounts);
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_mutation_failed',
          message: 'Failed to cancel transactions.',
          cause: error,
        ),
      );
    }
  }

  Future<Map<int, Account>> _loadAccounts(PostReceipt receipt) async {
    final ids = receipt.entries.map((e) => e.accountId).toSet();
    final accounts = await _repository.findAccountsByIds(ids);
    return {for (final a in accounts) a.id: a};
  }

  Failure? _validateAccounts(PostReceipt receipt, Map<int, Account> accounts) {
    for (final entry in receipt.entries) {
      final account = accounts[entry.accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account ${entry.accountId} does not exist.',
        );
      }
      if (account.archivedAt != null) {
        return Failure(
          code: 'account_archived',
          message: 'Account ${entry.accountId} is archived.',
        );
      }
    }
    return null;
  }

  Failure? _validateReceipt(
    PostReceipt receipt, {
    required bool allowNegativeAmounts,
  }) {
    if (receipt.details.isEmpty) {
      return const Failure(
        code: 'details_required',
        message: 'A transaction must have at least one detail.',
      );
    }
    if (receipt.entries.length < 2) {
      return const Failure(
        code: 'entries_required',
        message: 'A transaction must have at least two entries.',
      );
    }
    if ((!allowNegativeAmounts && receipt.primaryAmount.minorUnits <= 0) ||
        (allowNegativeAmounts && receipt.primaryAmount.minorUnits == 0)) {
      return const Failure(
        code: 'primary_amount_not_positive',
        message: 'Primary amount has an invalid sign.',
      );
    }
    for (final detail in receipt.details) {
      if (!_amountSignIsValid(
        amountMinor: detail.amount.minorUnits,
        expectsNegative: allowNegativeAmounts,
      )) {
        return Failure(
          code: 'detail_amount_sign_invalid',
          message:
              'Detail amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
      if (!detailTypeAllowedForPurpose(
        detailType: detail.type,
        businessPurpose: receipt.businessPurpose,
      )) {
        return Failure(
          code: 'detail_type_not_allowed',
          message:
              '${detail.type.name} is not allowed for '
              '${receipt.businessPurpose.name}.',
        );
      }
    }
    for (final entry in receipt.entries) {
      if (!_amountSignIsValid(
        amountMinor: entry.amount.minorUnits,
        expectsNegative: allowNegativeAmounts,
      )) {
        return Failure(
          code: 'entry_amount_sign_invalid',
          message:
              'Entry amount must be '
              '${allowNegativeAmounts ? 'negative' : 'positive'}.',
        );
      }
    }
    if (!entriesAreBalanced(receipt.entries)) {
      return const Failure(
        code: 'entries_not_balanced',
        message: 'Debit and credit entries must be balanced.',
      );
    }
    return null;
  }

  bool _amountSignIsValid({
    required int amountMinor,
    required bool expectsNegative,
  }) {
    return expectsNegative ? amountMinor < 0 : amountMinor > 0;
  }

  List<Account> _applyTransactionsToAccounts(
    Map<int, Account> accounts,
    List<Transaction> transactions,
  ) {
    final updated = Map<int, Account>.of(accounts);
    for (final transaction in transactions) {
      for (final accountId in transaction.accountIds) {
        final account = updated[accountId];
        if (account == null) {
          throw StateError('Account $accountId does not exist.');
        }
        updated[accountId] = account.applyTransaction(transaction);
      }
    }
    return updated.values.toList();
  }

  /// 把 builder 生成的"纯净蓝字"包装为 correction:从 original 继承
  /// root / parent / sourceKind / ownership / reimbursementExpenseAccountId,
  /// 其它字段沿用 newReceipt。
  PostReceipt _inheritFromOriginal(
    PostReceipt newReceipt,
    TransactionFact original,
  ) {
    final t = original.transaction;
    return newReceipt.copyWith(
      rootTransactionId: t.rootTransactionId,
      parentTransactionId: t.parentTransactionId,
      reimbursementExpenseAccountId:
          newReceipt.reimbursementExpenseAccountId ??
          t.reimbursementExpenseAccountId,
      sourceKind: t.sourceKind,
      ownership: t.ownership,
    );
  }

  /// 从 [original] 派生红字凭证:金额取负、方向不变、occurredAt 沿用原交易。
  PostReceipt _deriveReversal(TransactionFact original) {
    final t = original.transaction;
    return PostReceipt(
      businessPurpose: t.businessPurpose,
      occurredAt: t.occurredAt,
      primaryAmount: -t.primaryAmount,
      counterpartyName: t.counterpartyName,
      note: t.note,
      rootTransactionId: t.rootTransactionId,
      parentTransactionId: t.parentTransactionId,
      reimbursementExpenseAccountId: t.reimbursementExpenseAccountId,
      isExcludedFromStats: t.isExcludedFromStats,
      isExcludedFromBudget: t.isExcludedFromBudget,
      sourceKind: t.sourceKind,
      ownership: t.ownership,
      details: [
        for (final line in original.details)
          ReceiptDetail(
            lineNo: line.lineNo,
            type: line.type,
            amount: -line.amount,
          ),
      ],
      entries: [
        for (final entry in original.entries)
          ReceiptEntry(
            accountId: entry.accountId,
            direction: entry.direction,
            amount: -entry.amount,
          ),
      ],
    );
  }
}
