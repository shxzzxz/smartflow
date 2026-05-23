import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 日常收入 voucher。
///
/// 蓝字结构:
/// - details: 1 条 primaryIncome
/// - entries: settlement 借 / income 贷
class IncomeVoucher extends TransactionVoucher<IncomeVoucherInput> {
  const IncomeVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    IncomeVoucherInput input,
    VoucherContext ctx,
  ) async {
    final roleFailure = await ctx.validateAccountConstraints(
      usages: {input.receiveAccountId: AccountUsage.settlement},
      types: {
        input.incomeAccountId: {AccountType.income},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.dailyIncome,
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
            type: TransactionDetailType.primaryIncome,
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
            accountId: input.incomeAccountId,
            direction: EntryDirection.credit,
            amount: input.amount,
          ),
        ],
      ),
    );
  }
}

class IncomeVoucherInput {
  const IncomeVoucherInput({
    required this.amount,
    required this.receiveAccountId,
    required this.incomeAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int receiveAccountId;
  final int incomeAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
