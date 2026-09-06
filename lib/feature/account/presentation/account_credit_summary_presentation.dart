import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/finance/bill_status_badge.dart';
import 'package:smartflow/widget/business/finance/bill_summary_row.dart';

import '../../credit/presentation/bill_status_presentation.dart';

enum AccountCreditSummaryTone { neutral, primary, warning, success, danger }

class AccountCreditSummarySupportingItem {
  const AccountCreditSummarySupportingItem({
    required this.text,
    this.tone = AccountCreditSummaryTone.neutral,
  });

  final String text;
  final AccountCreditSummaryTone tone;
}

class AccountCreditSummaryStatus {
  const AccountCreditSummaryStatus({required this.label, required this.tone});

  final String label;
  final AccountCreditSummaryTone tone;
}

class AccountCreditSummaryPresentation {
  const AccountCreditSummaryPresentation({
    required this.id,
    required this.title,
    required this.amount,
    required this.supportingItems,
    required this.status,
    this.amountLabel,
  });

  final String id;
  final String title;
  final Money amount;
  final String? amountLabel;
  final List<AccountCreditSummarySupportingItem> supportingItems;
  final AccountCreditSummaryStatus status;
}

AccountCreditSummaryPresentation billAccountCreditSummary(
  BillSummaryReadModel bill,
) {
  final status = _billStatus(bill);
  return AccountCreditSummaryPresentation(
    id: bill.id,
    title: _billTitle(bill.period),
    amount: bill.pendingAmount,
    amountLabel: null,
    supportingItems: [
      if (bill.windowRepaymentDate != null)
        AccountCreditSummarySupportingItem(
          text: _billRepaymentLabel(bill.windowRepaymentDate!),
        ),
      AccountCreditSummarySupportingItem(text: '${bill.itemCount} 条明细'),
      if (bill.overdueItemCount > 0)
        AccountCreditSummarySupportingItem(
          text: '${bill.overdueItemCount} 条逾期',
          tone: AccountCreditSummaryTone.danger,
        ),
    ],
    status: status,
  );
}

BillSummaryRowPresentation billAccountSummaryRowPresentation(
  BillSummaryReadModel bill,
) {
  final summary = billAccountCreditSummary(bill);
  return BillSummaryRowPresentation(
    id: summary.id,
    title: summary.title,
    amount: summary.amount,
    amountLabel: summary.amountLabel,
    supportingTexts: [
      for (final item in summary.supportingItems)
        BillSummarySupportingText(
          text: item.text,
          tone: _billSummaryTone(item.tone),
        ),
    ],
    status: BillStatusBadgePresentation(
      label: summary.status.label,
      tone: _billSummaryTone(summary.status.tone),
    ),
  );
}

AccountCreditSummaryPresentation installmentAccountCreditSummary(
  InstallmentContractReadModel contract, {
  required AccountProfileKind accountKind,
}) {
  return AccountCreditSummaryPresentation(
    id: contract.id,
    title: _fullDate(contract.borrowingDate),
    amount: contract.principal,
    supportingItems: [
      AccountCreditSummarySupportingItem(
        text: _installmentSourceLabel(
          contract.sourceType,
          accountKind: accountKind,
        ),
      ),
      AccountCreditSummarySupportingItem(text: '${contract.totalPeriods} 期'),
      AccountCreditSummarySupportingItem(
        text: contract.stageTerms.stages.length > 1
            ? '${contract.stageTerms.stages.length} 个阶段'
            : _repaymentMethodLabel(
                contract.stageTerms.repayments.single.method,
              ),
      ),
    ],
    status: switch (contract.status) {
      InstallmentContractStatus.active => const AccountCreditSummaryStatus(
        label: '进行中',
        tone: AccountCreditSummaryTone.primary,
      ),
      InstallmentContractStatus.settled => const AccountCreditSummaryStatus(
        label: '已结清',
        tone: AccountCreditSummaryTone.success,
      ),
    },
  );
}

AccountCreditSummaryStatus _billStatus(BillSummaryReadModel bill) {
  if (bill.overdueItemCount > 0) {
    return const AccountCreditSummaryStatus(
      label: '已逾期',
      tone: AccountCreditSummaryTone.danger,
    );
  }
  return switch (bill.status) {
    BillStatus.open => AccountCreditSummaryStatus(
      label: billStatusLabel(BillStatus.open),
      tone: AccountCreditSummaryTone.primary,
    ),
    BillStatus.billed => AccountCreditSummaryStatus(
      label: billStatusLabel(BillStatus.billed),
      tone: AccountCreditSummaryTone.warning,
    ),
    BillStatus.settled => AccountCreditSummaryStatus(
      label: billStatusLabel(BillStatus.settled),
      tone: AccountCreditSummaryTone.success,
    ),
  };
}

String _billTitle(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月';
}

String _billRepaymentLabel(DateTime repaymentDate) {
  return '还款 ${repaymentDate.month.toString().padLeft(2, '0')}-'
      '${repaymentDate.day.toString().padLeft(2, '0')}';
}

String _fullDate(DateTime date) {
  return '${date.year}年${date.month.toString().padLeft(2, '0')}月'
      '${date.day.toString().padLeft(2, '0')}日';
}

String _installmentSourceLabel(
  InstallmentSourceType sourceType, {
  required AccountProfileKind accountKind,
}) {
  return switch (sourceType) {
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.disbursement => switch (accountKind) {
      AccountProfileKind.credit => '现金分期',
      AccountProfileKind.loan => '贷款分期',
      AccountProfileKind.fund ||
      AccountProfileKind.reimbursement ||
      AccountProfileKind.receivable ||
      AccountProfileKind.payable => '放款分期',
    },
  };
}

String _repaymentMethodLabel(InstallmentRepaymentMethod method) {
  return switch (method) {
    InstallmentRepaymentMethod.equalInstallment => '等额本息',
    InstallmentRepaymentMethod.equalPrincipal => '等额本金',
    InstallmentRepaymentMethod.interestFirst => '先息后本',
    InstallmentRepaymentMethod.flatFee => '一次性手续费',
    InstallmentRepaymentMethod.custom => '自定义',
  };
}

BillStatusTone _billSummaryTone(AccountCreditSummaryTone tone) {
  return switch (tone) {
    AccountCreditSummaryTone.neutral => BillStatusTone.neutral,
    AccountCreditSummaryTone.primary => BillStatusTone.primary,
    AccountCreditSummaryTone.warning => BillStatusTone.warning,
    AccountCreditSummaryTone.success => BillStatusTone.success,
    AccountCreditSummaryTone.danger => BillStatusTone.danger,
  };
}
