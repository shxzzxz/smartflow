import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account_usage.dart';
import '../entities/transaction_ownership.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import 'transaction_voucher.dart';

/// 还款 voucher。
///
/// 蓝字结构(可选项随输入开关):
/// - details: principal + [interest] + [fee] + [discount]
/// - entries: liability 借 + [interest expense 借] + [fee expense 借]
///            + [discount income 贷] + paidFrom 贷(=totalPaid)
///
/// 系统科目:
/// - 利息未指定时,从 systemAccountResolver.resolveDebtInterestExpense 取
/// - 折扣始终走 systemAccountResolver.resolveDiscountIncome
class RepaymentVoucher extends TransactionVoucher<RepaymentVoucherInput> {
  const RepaymentVoucher();

  @override
  Future<Result<PostTransactionCommand>> build(
    RepaymentVoucherInput input,
    VoucherContext ctx,
  ) async {
    final principal = input.principal;
    final interest = input.interest;
    final fee = input.fee;
    final discount = input.discount;

    if (principal.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_principal_not_positive',
          message: 'Repayment principal must be positive.',
        ),
      );
    }
    if (interest != null && interest.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment interest currency mismatch.',
        ),
      );
    }
    if (fee != null && fee.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment fee currency mismatch.',
        ),
      );
    }
    if (discount != null && discount.currency != principal.currency) {
      return const Result.failure(
        Failure(
          code: 'repayment_currency_mismatch',
          message: 'Repayment discount currency mismatch.',
        ),
      );
    }

    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;

    if (hasFee && input.feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_fee_account_required',
          message: 'Fee category is required when fee is positive.',
        ),
      );
    }

    final zero = Money.zero(currency: principal.currency);
    final totalPaid = principal +
        (hasInterest ? interest : zero) +
        (hasFee ? fee : zero) -
        (hasDiscount ? discount : zero);
    if (totalPaid.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_total_paid_not_positive',
          message: 'Repayment total paid must be positive.',
        ),
      );
    }

    final interestExpenseAccountId =
        hasInterest && input.interestExpenseAccountId == null
            ? await ctx.systemAccountResolver.resolveDebtInterestExpense(
                currencyCode: principal.currency,
              )
            : input.interestExpenseAccountId;
    final discountIncomeAccountId = hasDiscount
        ? await ctx.systemAccountResolver.resolveDiscountIncome(
            currencyCode: principal.currency,
          )
        : null;

    final roleFailure = await ctx.validateAccountConstraints(
      usages: {
        input.liabilityAccountId: AccountUsage.repaymentTarget,
        input.paidFromAccountId: AccountUsage.repaymentSource,
      },
      types: {
        if (hasInterest) interestExpenseAccountId!: {AccountType.expense},
        if (hasFee) input.feeExpenseAccountId!: {AccountType.expense},
        if (hasDiscount) discountIncomeAccountId!: {AccountType.income},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final details = <PostTransactionDetailInput>[
      PostTransactionDetailInput(
        lineNo: 1,
        type: TransactionDetailType.repaymentPrincipal,
        amount: principal,
      ),
      if (hasInterest)
        PostTransactionDetailInput(
          lineNo: 2,
          type: TransactionDetailType.repaymentInterest,
          amount: interest,
        ),
      if (hasFee)
        PostTransactionDetailInput(
          lineNo: hasInterest ? 3 : 2,
          type: TransactionDetailType.repaymentFee,
          amount: fee,
        ),
      if (hasDiscount)
        PostTransactionDetailInput(
          lineNo: 2 + (hasInterest ? 1 : 0) + (hasFee ? 1 : 0),
          type: TransactionDetailType.repaymentDiscount,
          amount: discount,
        ),
    ];

    final entries = <PostEntryInput>[
      PostEntryInput(
        accountId: input.liabilityAccountId,
        direction: EntryDirection.debit,
        amount: principal,
      ),
      if (hasInterest)
        PostEntryInput(
          accountId: interestExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: interest,
        ),
      if (hasFee)
        PostEntryInput(
          accountId: input.feeExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: fee,
        ),
      if (hasDiscount)
        PostEntryInput(
          accountId: discountIncomeAccountId!,
          direction: EntryDirection.credit,
          amount: discount,
        ),
      PostEntryInput(
        accountId: input.paidFromAccountId,
        direction: EntryDirection.credit,
        amount: totalPaid,
      ),
    ];

    return Result.success(
      PostTransactionCommand(
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: input.occurredAt,
        currencyCode: principal.currency,
        primaryAmount: totalPaid,
        counterpartyName: input.counterpartyName,
        note: input.note,
        ownership: input.ownership,
        isExcludedFromStats: input.isExcludedFromStats,
        isExcludedFromBudget: input.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }
}

class RepaymentVoucherInput {
  const RepaymentVoucherInput({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.interestExpenseAccountId,
    this.feeExpenseAccountId,
    this.counterpartyName,
    this.note,
    this.ownership,
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
  });

  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int liabilityAccountId;
  final int paidFromAccountId;
  final int? interestExpenseAccountId;
  final int? feeExpenseAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final TransactionOwnership? ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
