import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../entities/transaction.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 报销到账 voucher。依赖 advance 父交易。
///
/// 蓝字结构:
/// - details: reimbursementReceiptMain
/// - entries: receive 借 / receivable 贷
///
/// 编辑路径下,input.selfPrimaryAddback 应填原到账自身金额,以便对剩余 outstanding 做加回。
class ReimbursementReceiptVoucher
    extends TransactionVoucher<ReimbursementReceiptVoucherInput> {
  const ReimbursementReceiptVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    ReimbursementReceiptVoucherInput input,
    VoucherContext ctx,
  ) async {
    if (input.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }

    final advance = await ctx.queryService.findTransactionById(
      input.advanceTransactionId,
    );
    final advanceFailure = validateAdvance(advance, input.amount.currency);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    final summary = await ctx.queryService.getReimbursementSummary(advance!.id);
    if (summary == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_summary_unavailable',
          message: 'Cannot resolve reimbursement state.',
        ),
      );
    }
    if (summary.isClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }

    final addback = input.selfPrimaryAddback ??
        Money.zero(currency: input.amount.currency);
    final remaining = summary.outstanding + addback;
    if (input.amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message: 'Receipt exceeds outstanding receivable '
              '(${remaining.format(withCurrency: true)}).',
        ),
      );
    }

    final roleFailure = await ctx.validateAccountUsages({
      input.receiveAccountId: AccountUsage.settlement,
      input.receivableAccountId: AccountUsage.reimbursement,
    });
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: input.occurredAt,
        currencyCode: input.amount.currency,
        primaryAmount: input.amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: input.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.receiveAccountId,
            direction: EntryDirection.debit,
            amount: input.amount,
          ),
          PostEntryInput(
            accountId: input.receivableAccountId,
            direction: EntryDirection.credit,
            amount: input.amount,
          ),
        ],
      ),
    );
  }
}

class ReimbursementReceiptVoucherInput {
  const ReimbursementReceiptVoucherInput({
    required this.amount,
    required this.advanceTransactionId,
    required this.receivableAccountId,
    required this.receiveAccountId,
    required this.occurredAt,
    this.selfPrimaryAddback,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int advanceTransactionId;
  final int receivableAccountId;
  final int receiveAccountId;
  final DateTime occurredAt;
  final Money? selfPrimaryAddback;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

/// Reimbursement receipt / close 共用的 advance 父交易校验。
Failure? validateAdvance(Transaction? advance, String currencyCode) {
  if (advance == null) {
    return const Failure(
      code: 'reimbursement_advance_not_found',
      message: 'Reimbursement advance not found.',
    );
  }
  if (advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
    return const Failure(
      code: 'reimbursement_parent_not_advance',
      message: 'Parent transaction is not a reimbursement advance.',
    );
  }
  if (advance.businessState != BusinessState.current) {
    return const Failure(
      code: 'reimbursement_advance_not_current',
      message: 'Reimbursement advance is not current.',
    );
  }
  if (advance.currencyCode != currencyCode) {
    return const Failure(
      code: 'reimbursement_currency_mismatch',
      message: 'Currency must match the reimbursement advance.',
    );
  }
  return null;
}
