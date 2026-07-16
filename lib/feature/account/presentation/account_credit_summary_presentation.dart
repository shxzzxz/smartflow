import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';

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
  });

  final String id;
  final String title;
  final Money amount;
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
    amount: bill.pendingPrincipal,
    supportingItems: [
      AccountCreditSummarySupportingItem(text: _billDueLabel(bill.dueDate)),
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

AccountCreditSummaryPresentation installmentAccountCreditSummary(
  InstallmentContractReadModel contract, {
  required bool isCreditAccount,
}) {
  return AccountCreditSummaryPresentation(
    id: contract.id,
    title: _fullDate(contract.borrowingDate),
    amount: contract.principal,
    supportingItems: [
      AccountCreditSummarySupportingItem(
        text: _installmentSourceLabel(
          contract.sourceType,
          isCreditAccount: isCreditAccount,
        ),
      ),
      AccountCreditSummarySupportingItem(text: '${contract.totalPeriods} 期'),
      AccountCreditSummarySupportingItem(
        text: _repaymentMethodLabel(contract.repaymentMethod),
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
    BillStatus.open => const AccountCreditSummaryStatus(
      label: '累积中',
      tone: AccountCreditSummaryTone.primary,
    ),
    BillStatus.billed => const AccountCreditSummaryStatus(
      label: '已出账',
      tone: AccountCreditSummaryTone.warning,
    ),
    BillStatus.settled => const AccountCreditSummaryStatus(
      label: '已了结',
      tone: AccountCreditSummaryTone.success,
    ),
  };
}

String _billTitle(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月';
}

String _billDueLabel(DateTime? dueDate) {
  if (dueDate == null) return '无到期日';
  return '到期 ${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
}

String _fullDate(DateTime date) {
  return '${date.year}年${date.month.toString().padLeft(2, '0')}月'
      '${date.day.toString().padLeft(2, '0')}日';
}

String _installmentSourceLabel(
  InstallmentSourceType sourceType, {
  required bool isCreditAccount,
}) {
  return switch (sourceType) {
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.disbursement => isCreditAccount ? '现金分期' : '贷款分期',
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
