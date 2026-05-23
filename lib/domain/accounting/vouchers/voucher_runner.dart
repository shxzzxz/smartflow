import '../../../core/result/result.dart';
import '../commands/transaction_commands.dart';
import '../enums/accounting_enums.dart';
import '../ledger/poster.dart';
import '../ledger/posting_protocol.dart';
import '../read_models/transaction_read_models.dart';
import 'transaction_voucher.dart';

/// Voucher 编排器:把 voucher 组装出的蓝字凭证 + 红字反向(如有)+ 状态翻转
/// 整合成一次过账调用。service 层只持有一个 runner,所有写入命令统一走这里。
class VoucherRunner {
  const VoucherRunner({required this.poster, required this.context});

  final Poster poster;
  final VoucherContext context;

  /// 单笔蓝字凭证(create 路径)。
  Future<Result<CreatedTransactionResult>> runCreate<I>(
    TransactionVoucher<I> voucher,
    I input,
  ) async {
    final commandResult = await voucher.build(input, context);
    switch (commandResult) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        final post = await poster.post(value);
        switch (post) {
          case FailureResult(:final failure):
            return Result.failure(failure);
          case Success(:final value):
            return Result.success(_toCreated(value));
        }
    }
  }

  /// 一笔红字(冲掉 [original])+ 一笔新蓝字(correction 路径)。
  /// caller 应已确认 original.children 为空或结构匹配。
  Future<Result<CreatedTransactionResult>> runReplacement<I>({
    required TransactionVoucher<I> voucher,
    required I input,
    required TransactionDetail original,
  }) async {
    final replacementResult = await voucher.build(input, context);
    switch (replacementResult) {
      case FailureResult(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        final withMeta = _applyCorrectionMetadata(value, original);
        final reversal = buildReversalCommand(
          original,
          reason: MutationReason.correction,
        );
        final result = await poster.postMutation(
          stateUpdates: [
            TransactionStateUpdate(
              transactionId: original.transaction.id,
              businessState: BusinessState.replaced,
            ),
          ],
          commands: [reversal, withMeta],
        );
        switch (result) {
          case FailureResult(:final failure):
            return Result.failure(failure);
          case Success(:final value):
            return Result.success(_toCreated(value.last));
        }
    }
  }

  /// 仅红字(delete 路径)。把 [details] 全部翻转 + 状态置为 canceled。
  Future<Result<void>> runCancellation({
    required List<TransactionDetail> details,
  }) async {
    final commands = [
      for (final d in details)
        buildReversalCommand(d, reason: MutationReason.delete),
    ];
    final stateUpdates = [
      for (final d in details)
        TransactionStateUpdate(
          transactionId: d.transaction.id,
          businessState: BusinessState.canceled,
        ),
    ];
    final result = await poster.postMutation(
      stateUpdates: stateUpdates,
      commands: commands,
    );
    return result.when(
      success: (_) => const Result.success(null),
      failure: Result.failure,
    );
  }
}

CreatedTransactionResult _toCreated(PostTransactionResult post) =>
    CreatedTransactionResult(
      transactionId: post.transactionId,
      rootTransactionId: post.rootTransactionId,
    );

/// 把 voucher 输出的"新鲜蓝字"包装成 correction:
/// - 继承 original 的 root / parent / sourceKind / ownership
/// - 设 mutationKind = correction, mutationPreviousTransactionId = original.id
PostTransactionCommand _applyCorrectionMetadata(
  PostTransactionCommand replacement,
  TransactionDetail original,
) {
  final t = original.transaction;
  return PostTransactionCommand(
    businessPurpose: replacement.businessPurpose,
    occurredAt: replacement.occurredAt,
    currencyCode: replacement.currencyCode,
    primaryAmount: replacement.primaryAmount,
    counterpartyName: replacement.counterpartyName,
    note: replacement.note,
    rootTransactionId: t.rootTransactionId,
    parentTransactionId: t.parentTransactionId,
    reimbursementExpenseAccountId:
        replacement.reimbursementExpenseAccountId ??
            t.reimbursementExpenseAccountId,
    mutationKind: MutationKind.correction,
    mutationPreviousTransactionId: t.id,
    isExcludedFromStats: replacement.isExcludedFromStats,
    isExcludedFromBudget: replacement.isExcludedFromBudget,
    sourceKind: t.sourceKind,
    ownership: t.ownership,
    details: replacement.details,
    entries: replacement.entries,
  );
}

/// 根据 [detail] 计算等量反向的红字凭证(纯函数变换,无 DB 访问)。
PostTransactionCommand buildReversalCommand(
  TransactionDetail detail, {
  required MutationReason reason,
}) {
  final t = detail.transaction;
  return PostTransactionCommand(
    businessPurpose: t.businessPurpose,
    occurredAt: DateTime.now(),
    currencyCode: t.currencyCode,
    primaryAmount: -t.primaryAmount,
    counterpartyName: t.counterpartyName,
    note: t.note,
    rootTransactionId: t.rootTransactionId,
    parentTransactionId: t.parentTransactionId,
    reimbursementExpenseAccountId: t.reimbursementExpenseAccountId,
    mutationKind: MutationKind.reversal,
    mutationPreviousTransactionId: t.id,
    mutationReason: reason,
    businessState: BusinessState.compensation,
    isExcludedFromStats: t.isExcludedFromStats,
    isExcludedFromBudget: t.isExcludedFromBudget,
    sourceKind: t.sourceKind,
    ownership: t.ownership,
    details: [
      for (final line in detail.details)
        PostTransactionDetailInput(
          lineNo: line.lineNo,
          type: line.type,
          amount: -line.amount,
        ),
    ],
    entries: [
      for (final entry in detail.entries)
        PostEntryInput(
          accountId: entry.accountId,
          direction: entry.direction,
          amount: -entry.amount,
        ),
    ],
  );
}

/// 判断 [replacement] 与 [original] 在账户结构上是否一致(忽略金额差异)。
/// 用于编辑场景:若有子记录但结构未变,允许 metadata-only 更新;否则禁止编辑。
bool structureMatches(
  PostTransactionCommand replacement,
  TransactionDetail original,
) {
  if (original.transaction.businessPurpose != replacement.businessPurpose) {
    return false;
  }
  final origKeys = {
    for (final e in original.entries) (e.accountId, e.direction),
  };
  final repKeys = {
    for (final e in replacement.entries) (e.accountId, e.direction),
  };
  if (origKeys.length != repKeys.length) return false;
  return origKeys.difference(repKeys).isEmpty;
}
