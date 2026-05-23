import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 日常支出 voucher。
///
/// 蓝字结构:
/// - details: 1 条 primaryExpense
/// - entries: expense 借 / settlement 贷
class ExpenseVoucher extends TransactionVoucher<ExpenseVoucherInput> {
  const ExpenseVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    ExpenseVoucherInput input,
    VoucherContext ctx,
  ) async {
    final roleFailure = await ctx.validateAccountConstraints(
      usages: {input.paidFromAccountId: AccountUsage.settlement},
      types: {
        input.expenseAccountId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: input.occurredAt,
        currencyCode: input.amount.currency,
        primaryAmount: input.amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: input.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.expenseAccountId,
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

class ExpenseVoucherInput {
  const ExpenseVoucherInput({
    required this.amount,
    required this.paidFromAccountId,
    required this.expenseAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int paidFromAccountId;
  final int expenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
