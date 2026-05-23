import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../entities/transaction_ownership.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 借入 voucher。
///
/// 蓝字结构:
/// - details: borrowingPrincipal
/// - entries: 借入资金账户 借 / liability 贷
///
/// 若 receiveAccountId 为 null,则借方走系统期初权益科目(等价"债务直接进入家庭资产")。
class BorrowingVoucher extends TransactionVoucher<BorrowingVoucherInput> {
  const BorrowingVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    BorrowingVoucherInput input,
    VoucherContext ctx,
  ) async {
    if (input.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'borrowing_amount_not_positive',
          message: 'Borrowing amount must be positive.',
        ),
      );
    }

    final receiveAccountId = input.receiveAccountId;
    final useSystemEquity = receiveAccountId == null;
    final roleFailure = await ctx.validateAccountUsages({
      input.liabilityAccountId: AccountUsage.borrowingLiability,
      if (!useSystemEquity) receiveAccountId: AccountUsage.fund,
    });
    if (roleFailure != null) return Result.failure(roleFailure);

    final debitAccountId = useSystemEquity
        ? await ctx.systemAccountResolver.resolveOpeningBalance(
            currencyCode: input.amount.currency,
          )
        : receiveAccountId;

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: input.occurredAt,
        currencyCode: input.amount.currency,
        primaryAmount: input.amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        ownership: input.ownership,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.borrowingPrincipal,
            amount: input.amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: debitAccountId,
            direction: EntryDirection.debit,
            amount: input.amount,
          ),
          PostEntryInput(
            accountId: input.liabilityAccountId,
            direction: EntryDirection.credit,
            amount: input.amount,
          ),
        ],
      ),
    );
  }
}

class BorrowingVoucherInput {
  const BorrowingVoucherInput({
    required this.amount,
    required this.liabilityAccountId,
    required this.occurredAt,
    this.receiveAccountId,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int liabilityAccountId;
  final int? receiveAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
