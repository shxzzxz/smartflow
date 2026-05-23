import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'reimbursement_receipt_voucher.dart' show validateAdvance;
import 'transaction_voucher.dart';

/// 结束报销 voucher。依赖 advance 父交易。
///
/// 蓝字结构(根据 actual vs outstanding 判定 gap):
/// - details: reimbursementCloseMain + [gapIncome 或 gapExpense]
/// - entries: receive 借(若 actual>0)+ receivable 贷
///            + 多收时 → 系统 reimbursement_gap_income 贷
///            + 少收时 → advance 的原报销支出科目 借
///
/// outstanding 的来源:
/// - create 路径:input.outstandingOverride = null → 从 advance summary 计算
/// - correct 路径:input.outstandingOverride = 原 close-main detail 金额
class ReimbursementCloseVoucher
    extends TransactionVoucher<ReimbursementCloseVoucherInput> {
  const ReimbursementCloseVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    ReimbursementCloseVoucherInput input,
    VoucherContext ctx,
  ) async {
    final actual = input.actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Final receipt amount cannot be negative.',
        ),
      );
    }

    final advance = await ctx.queryService.findTransactionById(
      input.advanceTransactionId,
    );
    final advanceFailure = validateAdvance(advance, actual.currency);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    Money outstanding;
    if (input.outstandingOverride != null) {
      if (input.outstandingOverride!.currency != actual.currency) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_currency_mismatch',
            message: 'Currency must match the reimbursement advance.',
          ),
        );
      }
      outstanding = input.outstandingOverride!;
    } else {
      final summary = await ctx.queryService.getReimbursementSummary(
        advance!.id,
      );
      if (summary == null || summary.isClosed) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_already_closed',
            message: 'This reimbursement chain is already closed.',
          ),
        );
      }
      outstanding = summary.outstanding;
    }

    final gap = actual - outstanding;
    final hasOverGap = gap.minorUnits > 0;
    final hasUnderGap = gap.minorUnits < 0;

    final details = <PostTransactionDetailInput>[
      PostTransactionDetailInput(
        lineNo: 1,
        type: TransactionDetailType.reimbursementCloseMain,
        amount: outstanding,
      ),
      if (hasOverGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapIncome,
          amount: gap,
        ),
      if (hasUnderGap)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapExpense,
          amount: gap.abs(),
        ),
    ];

    final entries = <PostEntryInput>[
      if (actual.minorUnits > 0)
        PostEntryInput(
          accountId: input.receiveAccountId,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      PostEntryInput(
        accountId: input.receivableAccountId,
        direction: EntryDirection.credit,
        amount: outstanding,
      ),
    ];

    if (hasOverGap) {
      final gapAccountId = await ctx.systemAccountResolver
          .resolveReimbursementGapIncome(currencyCode: actual.currency);
      entries.add(
        PostEntryInput(
          accountId: gapAccountId,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (hasUnderGap) {
      final originalExpenseId = advance!.reimbursementExpenseAccountId;
      if (originalExpenseId == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_close_expense_missing',
            message:
                'Original reimbursement expense category is not recorded.',
          ),
        );
      }
      entries.add(
        PostEntryInput(
          accountId: originalExpenseId,
          direction: EntryDirection.debit,
          amount: gap.abs(),
        ),
      );
    }

    final roleFailure = await ctx.validateAccountUsages({
      if (actual.minorUnits > 0)
        input.receiveAccountId: AccountUsage.settlement,
      input.receivableAccountId: AccountUsage.reimbursement,
    });
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: input.occurredAt,
        currencyCode: actual.currency,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: input.counterpartyName,
        note: input.note,
        rootTransactionId: advance!.rootTransactionId,
        parentTransactionId: advance.id,
        reimbursementExpenseAccountId: advance.reimbursementExpenseAccountId,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }
}

class ReimbursementCloseVoucherInput {
  const ReimbursementCloseVoucherInput({
    required this.actualReceivedAmount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.outstandingOverride,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money actualReceivedAmount;
  final int advanceTransactionId;
  final int receivableAccountId;
  final int receiveAccountId;
  final DateTime occurredAt;

  /// 编辑场景:从原 close 交易的 main detail 取 outstanding,以保持口径稳定。
  final Money? outstandingOverride;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
