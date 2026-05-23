import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 报销垫付 voucher。
///
/// 蓝字结构:
/// - details: reimbursementAdvanceMain
/// - entries: receivable 借 / paidFrom 贷
class ReimbursementAdvanceVoucher
    extends TransactionVoucher<ReimbursementAdvanceVoucherInput> {
  const ReimbursementAdvanceVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    ReimbursementAdvanceVoucherInput input,
    VoucherContext ctx,
  ) async {
    if (input.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Advance amount must be positive.',
        ),
      );
    }

    final roleFailure = await ctx.validateAccountConstraints(
      usages: {
        input.receivableAccountId: AccountUsage.reimbursement,
        input.paidFromAccountId: AccountUsage.settlement,
      },
      types: {
        input.expenseCategoryId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: input.occurredAt,
        currencyCode: input.amount.currency,
        primaryAmount: input.amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        reimbursementExpenseAccountId: input.expenseCategoryId,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.reimbursementAdvanceMain,
            amount: input.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.receivableAccountId,
            direction: EntryDirection.debit,
            amount: input.amount,
          ),
          PostEntryInput(
            accountId: input.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: input.amount,
          ),
        ],
      ),
    );
  }
}

class ReimbursementAdvanceVoucherInput {
  const ReimbursementAdvanceVoucherInput({
    required this.amount,
    required this.receivableAccountId,
    required this.paidFromAccountId,
    required this.expenseCategoryId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int receivableAccountId;
  final int paidFromAccountId;
  final int expenseCategoryId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
