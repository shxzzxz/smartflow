import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 期初余额 voucher。
///
/// 蓝字结构(方向由账户类型 + 期初符号决定):
/// - details: openingBalanceMain
/// - entries: 账户 ± / 系统期初权益账户 ∓ (金额恒正,方向二选一)
class OpeningBalanceVoucher
    extends TransactionVoucher<OpeningBalanceVoucherInput> {
  const OpeningBalanceVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    OpeningBalanceVoucherInput input,
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
          message: 'Cannot initialize archived account.',
        ),
      );
    }
    if (account.currencyCode != input.amount.currency) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_currency_mismatch',
          message: 'Opening balance currency must match account currency.',
        ),
      );
    }
    if (input.amount.minorUnits == 0) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_zero',
          message: 'Opening balance amount cannot be zero.',
        ),
      );
    }

    final amount = input.amount.abs();
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: input.amount.minorUnits,
    );
    final equityDirection = accountDirection == EntryDirection.debit
        ? EntryDirection.credit
        : EntryDirection.debit;

    final equityAccountId = await ctx.systemAccountResolver
        .resolveOpeningBalance(currencyCode: amount.currency);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.openingBalance,
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
            type: TransactionDetailType.openingBalanceMain,
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

class OpeningBalanceVoucherInput {
  const OpeningBalanceVoucherInput({
    required this.accountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final int accountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

/// 余额变化方向:对资产/费用账户,正变化记借方;对负债/收入/权益,正变化记贷方。
/// OpeningBalanceVoucher 与 BalanceAdjustmentVoucher 共用此公式。
EntryDirection directionForBalanceDelta({
  required AccountType accountType,
  required int deltaMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  final increase = deltaMinor > 0;
  if (increasesOnDebit) {
    return increase ? EntryDirection.debit : EntryDirection.credit;
  }
  return increase ? EntryDirection.credit : EntryDirection.debit;
}
