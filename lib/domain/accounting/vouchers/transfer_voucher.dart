import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 转账 voucher。
///
/// 蓝字结构(可带手续费):
/// - details: transferMain + [transferFee]
/// - entries: to 借 + [feeExpense 借] + from 贷(=amount + fee)
class TransferVoucher extends TransactionVoucher<TransferVoucherInput> {
  const TransferVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    TransferVoucherInput input,
    VoucherContext ctx,
  ) async {
    final feeFailure = _validateFee(input);
    if (feeFailure != null) return Result.failure(feeFailure);

    if (input.fromAccountId == input.toAccountId) {
      return const Result.failure(
        Failure(
          code: 'transfer_accounts_must_differ',
          message: 'Transfer source and target accounts must differ.',
        ),
      );
    }

    final feeAmount = input.feeAmount;
    final feeExpenseAccountId = input.feeExpenseAccountId;
    final hasFee = feeAmount != null && feeAmount.minorUnits > 0;
    final totalPaid = hasFee ? input.amount + feeAmount : input.amount;

    final roleFailure = await ctx.validateAccountConstraints(
      usages: {
        input.fromAccountId: AccountUsage.settlement,
        input.toAccountId: AccountUsage.settlement,
      },
      types: {
        if (hasFee) feeExpenseAccountId!: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.transfer,
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
            type: TransactionDetailType.transferMain,
            amount: input.amount,
          ),
          if (hasFee)
            PostTransactionDetailInput(
              lineNo: 2,
              type: TransactionDetailType.transferFee,
              amount: feeAmount,
            ),
        ],
        entries: [
          PostEntryInput(
            accountId: input.toAccountId,
            direction: EntryDirection.debit,
            amount: input.amount,
          ),
          if (hasFee)
            PostEntryInput(
              accountId: feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: feeAmount,
            ),
          PostEntryInput(
            accountId: input.fromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Failure? _validateFee(TransferVoucherInput input) {
    final feeAmount = input.feeAmount;
    final feeExpenseAccountId = input.feeExpenseAccountId;
    if (feeAmount == null) {
      return feeExpenseAccountId == null
          ? null
          : const Failure(
              code: 'transfer_fee_amount_required',
              message:
                  'Transfer fee amount is required when fee account is set.',
            );
    }
    if (feeAmount.currency != input.amount.currency) {
      return const Failure(
        code: 'transfer_fee_currency_mismatch',
        message: 'Transfer fee currency must match transfer amount currency.',
      );
    }
    if (feeAmount.minorUnits < 0) {
      return const Failure(
        code: 'transfer_fee_negative',
        message: 'Transfer fee cannot be negative.',
      );
    }
    if (feeAmount.minorUnits == 0) {
      return feeExpenseAccountId == null
          ? null
          : const Failure(
              code: 'transfer_fee_positive_required',
              message: 'Transfer fee must be positive when fee account is set.',
            );
    }
    if (feeExpenseAccountId == null) {
      return const Failure(
        code: 'transfer_fee_account_required',
        message:
            'Transfer fee account is required when fee amount is positive.',
      );
    }
    return null;
  }
}

class TransferVoucherInput {
  const TransferVoucherInput({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.occurredAt,
    this.feeAmount,
    this.feeExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money amount;
  final int fromAccountId;
  final int toAccountId;
  final DateTime occurredAt;
  final Money? feeAmount;
  final int? feeExpenseAccountId;
  final String? counterpartyName;
  final String? note;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
