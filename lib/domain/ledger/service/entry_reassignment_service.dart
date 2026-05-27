import '../entity/account.dart';
import '../entity/entry.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/post_receipt.dart';

/// `updateTransactionBasics` 路径所需的领域服务:
/// 1. 在一笔交易的 entries 中识别"结算账户" / "报销应收账户" 这两类 entry,
///    供 UI 决定要换哪一条 entry 的账户;
/// 2. 给定 reassignment 列表,计算受影响账户的新余额。
///
/// 无状态,无 I/O;caller 负责把所需 [Account] / [Entry] / [scopes] 准备好。
class EntryReassignmentService {
  const EntryReassignmentService();

  /// 在一笔交易的 entries 中识别"结算账户" entry。
  ///
  /// settlement 必须落在 asset / liability 账户;
  /// 不同 [BusinessPurpose] 决定 entry 方向;
  /// `reimbursementAdvance` 时排除 receivable(asset+debit)。
  Entry? findSettlementEntry({
    required BusinessPurpose businessPurpose,
    required List<Entry> entries,
    required Map<String, AccountType> accountTypes,
  }) {
    final direction = switch (businessPurpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.reimbursementAdvance ||
      BusinessPurpose.debtRepayment => EntryDirection.credit,
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.refund ||
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose ||
      BusinessPurpose.borrowing => EntryDirection.debit,
      _ => null,
    };
    if (direction == null) return null;
    for (final entry in entries) {
      final accountType = accountTypes[entry.accountId];
      final settlementType =
          accountType == AccountType.asset ||
          accountType == AccountType.liability;
      final isReimbursementReceivable =
          businessPurpose == BusinessPurpose.reimbursementAdvance &&
          entry.direction == EntryDirection.debit &&
          accountType == AccountType.asset;
      if (settlementType &&
          !isReimbursementReceivable &&
          entry.direction == direction) {
        return entry;
      }
    }
    return null;
  }

  /// 在 reimbursementAdvance 的 entries 中识别 receivable(asset+debit) entry。
  Entry? findReimbursementReceivableEntry({
    required List<Entry> entries,
    required Map<String, AccountType> accountTypes,
  }) {
    for (final entry in entries) {
      if (accountTypes[entry.accountId] == AccountType.asset &&
          entry.direction == EntryDirection.debit) {
        return entry;
      }
    }
    return null;
  }

  /// 按 reassignment 列表,把账户的 entry 影响"减去旧账户、加到新账户"。
  ///
  /// [account] 必须已含所有 from/to 账户的当前快照;
  /// [scopes] 描述哪些 entry 受 reassignment 影响 — 通常包含主交易及其
  /// `state == current` 的 child 交易,各以一个 scope 出现。
  List<Account> recomputeAccountsForReassignments({
    required Map<String, Account> accounts,
    required List<EntryReassignmentScope> scopes,
    required List<EntryAccountReassignment> reassignments,
  }) {
    if (reassignments.isEmpty) return const [];
    final updated = Map<String, Account>.of(accounts);

    for (final reassignment in reassignments) {
      final oldAccount = updated[reassignment.fromAccountId];
      final newAccount = updated[reassignment.toAccountId];
      if (oldAccount == null || newAccount == null) {
        throw StateError(
          'Cannot reassign entry account because account is missing.',
        );
      }
      if (reassignment.fromAccountId == reassignment.toAccountId) {
        continue;
      }
      final affectedEntries = _entriesForReassignment(scopes, reassignment);
      for (final entry in affectedEntries) {
        final oldImpact = ReceiptEntry(
          accountId: reassignment.fromAccountId,
          direction: entry.direction,
          amount: entry.amount,
        );
        final newImpact = ReceiptEntry(
          accountId: reassignment.toAccountId,
          direction: entry.direction,
          amount: entry.amount,
        );
        updated[oldAccount.id] = updated[oldAccount.id]!.removeEntryImpact(
          oldImpact,
        );
        updated[newAccount.id] = updated[newAccount.id]!.applyEntryImpact(
          newImpact,
        );
      }
    }
    return updated.values.toList();
  }

  List<Entry> _entriesForReassignment(
    List<EntryReassignmentScope> scopes,
    EntryAccountReassignment reassignment,
  ) {
    final transactionId = reassignment.transactionId;
    if (transactionId != null) {
      return [
        for (final scope in scopes)
          if (scope.transactionId == transactionId)
            for (final entry in scope.entries)
              if (entry.accountId == reassignment.fromAccountId) entry,
      ];
    }
    final rootTransactionId = reassignment.rootTransactionId!;
    return [
      for (final scope in scopes)
        if (scope.rootTransactionId == rootTransactionId &&
            scope.businessState == BusinessState.current)
          for (final entry in scope.entries)
            if (entry.accountId == reassignment.fromAccountId) entry,
    ];
  }
}

/// reassignment 的查找范围:某笔交易及其 entries 在 scope 内的身份信息。
class EntryReassignmentScope {
  const EntryReassignmentScope({
    required this.transactionId,
    required this.rootTransactionId,
    required this.businessState,
    required this.entries,
  });

  final String transactionId;
  final String rootTransactionId;
  final BusinessState businessState;
  final List<Entry> entries;
}
