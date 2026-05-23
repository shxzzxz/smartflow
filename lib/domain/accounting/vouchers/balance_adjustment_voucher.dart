import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'opening_balance_voucher.dart';
import 'transaction_voucher.dart';

/// 余额调整 voucher。仅支持资产/负债账户。
///
/// 蓝字结构(方向由账户类型 + 差额符号决定):
/// - details: balanceAdjustmentMain
/// - entries: 账户 ± / 系统期初权益账户 ∓ (金额 = 差额绝对值)
class BalanceAdjustmentVoucher
    extends TransactionVoucher<BalanceAdjustmentVoucherInput> {
  const BalanceAdjustmentVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    BalanceAdjustmentVoucherInput input,
    VoucherContext ctx,
  ) async {
    final account = await ctx.accountRepository.findAccountById(input.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot adjust archived account.',
        ),
      );
    }
    if (account.type != AccountType.asset &&
        account.type != AccountType.liability) {
      return const Result.failure(
        Failure(
          code: 'account_not_adjustable',
          message:
              'Only asset and liability accounts support balance adjustment.',
        ),
      );
    }
    if (account.currencyCode != input.targetBalance.currency) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_currency_mismatch',
          message: 'Target balance currency must match account currency.',
        ),
      );
    }

    final deltaMinor =
        input.targetBalance.minorUnits - account.balance.minorUnits;
    if (deltaMinor == 0) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_zero_delta',
          message: 'Balance is already at the target value.',
        ),
      );
    }

    final amount = Money(
      minorUnits: deltaMinor.abs(),
      currency: input.targetBalance.currency,
    );
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: deltaMinor,
    );
    final equityDirection = accountDirection == EntryDirection.debit
        ? EntryDirection.credit
        : EntryDirection.debit;

    final equityAccountId = await ctx.systemAccountResolver
        .resolveOpeningBalance(currencyCode: amount.currency);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: input.occurredAt,
        currencyCode: amount.currency,
        primaryAmount: amount,
        counterpartyName: input.counterpartyName,
        note: input.note,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: [
          PostTransactionDetailInput(
            lineNo: 1,
            type: TransactionDetailType.balanceAdjustmentMain,
            amount: amount,
          ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.accountId,
            direction: accountDirection,
            amount: amount,
          ),
          PostEntryInput(
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }
}

class BalanceAdjustmentVoucherInput {
  const BalanceAdjustmentVoucherInput({
    required this.accountId,
    required this.targetBalance,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final int accountId;
  final Money targetBalance;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
