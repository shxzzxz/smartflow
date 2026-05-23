import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 退款 voucher。依赖 parent 交易(日常支出或报销垫付)。
///
/// 蓝字结构:
/// - details: refundMain
/// - entries: refundTo 借 / parent 贡献的"被退回科目"贷
///   - parent 是 dailyExpense:credit 走原费用类账户
///   - parent 是 reimbursementAdvance:credit 走原 receivable 账户
///
/// 编辑路径下,input.selfPrimaryAddback 应填原退款自身金额,以便对剩余额度做加回。
class RefundVoucher extends TransactionVoucher<RefundVoucherInput> {
  const RefundVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    RefundVoucherInput input,
    VoucherContext ctx,
  ) async {
    if (input.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }
    final parentId = input.parentTransactionId;
    if (parentId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    final parent = await ctx.queryService.findTransactionById(parentId);
    if (parent == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    if (parent.businessPurpose != BusinessPurpose.dailyExpense &&
        parent.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_expense',
          message: 'Refund can only be applied to an expense transaction.',
        ),
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      final summary = await ctx.queryService.getReimbursementSummary(
        parent.rootTransactionId,
      );
      if (summary?.isClosed ?? false) {
        return const Result.failure(
          Failure(
            code: 'refund_parent_reimbursement_closed',
            message: 'Refund is not supported after reimbursement is closed.',
          ),
        );
      }
    }
    if (parent.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_current',
          message: 'Refund can only be applied to a current expense.',
        ),
      );
    }
    if (parent.currencyCode != input.amount.currency) {
      return const Result.failure(
        Failure(
          code: 'refund_currency_mismatch',
          message: 'Refund currency must match the original expense.',
        ),
      );
    }

    final refunded = await ctx.queryService.getRefundedTotal(
      parent.rootTransactionId,
      currencyCode: parent.currencyCode,
    );
    final addback = input.selfPrimaryAddback ??
        Money.zero(currency: parent.currencyCode);
    final remaining = parent.primaryAmount - refunded + addback;
    if (input.amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message: 'Refund exceeds remaining refundable amount '
              '(${remaining.format(withCurrency: true)}).',
        ),
      );
    }

    final refundCreditAccountId = await _findRefundCreditAccountId(
      parentId: parent.id,
      parentPurpose: parent.businessPurpose,
      ctx: ctx,
    );
    if (refundCreditAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_expense_account_not_found',
          message: 'Original refund target account cannot be located.',
        ),
      );
    }

    final roleFailure = await ctx.validateAccountUsages({
      input.refundToAccountId: AccountUsage.settlement,
    });
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.refund,
        occurredAt: input.occurredAt,
        currencyCode: input.amount.currency,
        primaryAmount: input.amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        rootTransactionId: parent.rootTransactionId,
        parentTransactionId: parent.id,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: input.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.refundToAccountId,
            direction: EntryDirection.debit,
            amount: input.amount,
          ),
          PostEntryInput(
            accountId: refundCreditAccountId,
            direction: EntryDirection.credit,
            amount: input.amount,
          ),
        ],
      ),
    );
  }

  Future<int?> _findRefundCreditAccountId({
    required int parentId,
    required BusinessPurpose parentPurpose,
    required VoucherContext ctx,
  }) async {
    final view = await ctx.queryService.watchTransactionDetail(parentId).first;
    if (view == null) return null;
    final accountTypes = await ctx.loadAccountTypes(
      view.entries.map((e) => e.accountId),
    );
    for (final entry in view.entries) {
      final accountType = accountTypes[entry.accountId];
      final isDailyExpenseTarget =
          parentPurpose == BusinessPurpose.dailyExpense &&
              accountType == AccountType.expense &&
              entry.direction == EntryDirection.debit;
      final isAdvanceTarget =
          parentPurpose == BusinessPurpose.reimbursementAdvance &&
              accountType == AccountType.asset &&
              entry.direction == EntryDirection.debit;
      if (isDailyExpenseTarget || isAdvanceTarget) {
        return entry.accountId;
      }
    }
    return null;
  }
}

class RefundVoucherInput {
  const RefundVoucherInput({
    required this.amount,
    required this.parentTransactionId,
    required this.refundToAccountId,
    required this.occurredAt,
    this.selfPrimaryAddback,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int? parentTransactionId;
  final int refundToAccountId;
  final DateTime occurredAt;

  /// 编辑场景:原退款自身金额。validate 时加回到剩余额度;create 路径传 null。
  final Money? selfPrimaryAddback;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
