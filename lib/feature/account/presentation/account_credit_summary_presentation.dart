import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/finance/finance_summary_row.dart';

import '../../credit/presentation/bill_status_presentation.dart';

FinanceSummaryRowPresentation billAccountCreditSummary(
  BillSummaryReadModel bill,
) {
  final status = _billStatus(bill);
  return FinanceSummaryRowPresentation(
    id: bill.id,
    title: _billTitle(bill.period),
    amount: bill.pendingAmount,
    amountLabel: null,
    supportingTexts: [
      // Kept for legacy read models; persisted bill summaries no longer
      // populate a bill-level repayment date.
      if (bill.windowRepaymentDate != null)
        AppSupportingText(_billRepaymentLabel(bill.windowRepaymentDate!)),
      AppSupportingText('${bill.itemCount} 条明细'),
      if (bill.overdueItemCount > 0)
        AppSupportingText(
          '${bill.overdueItemCount} 条逾期',
          tone: AppStatusTone.danger,
        ),
    ],
    status: status,
  );
}

String _billRepaymentLabel(DateTime repaymentDate) {
  return '还款 ${repaymentDate.month.toString().padLeft(2, '0')}-'
      '${repaymentDate.day.toString().padLeft(2, '0')}';
}

FinanceSummaryRowPresentation installmentAccountCreditSummary(
  InstallmentContractReadModel contract, {
  required AccountProfileKind accountKind,
}) {
  return FinanceSummaryRowPresentation(
    id: contract.id,
    title: contract.name,
    amount: contract.principal,
    supportingTexts: [
      AppSupportingText(
        _installmentSourceLabel(contract.sourceType, accountKind: accountKind),
      ),
      AppSupportingText('${contract.totalPeriods} 期'),
      AppSupportingText(
        contract.stageTerms.stages.length > 1
            ? '${contract.stageTerms.stages.length} 个阶段'
            : _repaymentMethodLabel(
                contract.stageTerms.repayments.single.method,
              ),
      ),
    ],
    status: switch (contract.status) {
      InstallmentContractStatus.active => const AppStatusBadgePresentation(
        label: '进行中',
        tone: AppStatusTone.primary,
      ),
      InstallmentContractStatus.settled => const AppStatusBadgePresentation(
        label: '已结清',
        tone: AppStatusTone.success,
      ),
    },
  );
}

AppStatusBadgePresentation _billStatus(BillSummaryReadModel bill) {
  if (bill.overdueItemCount > 0) {
    return const AppStatusBadgePresentation(
      label: '已逾期',
      tone: AppStatusTone.danger,
    );
  }
  return billStatusBadgePresentation(bill.status);
}

String _billTitle(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月';
}

String _installmentSourceLabel(
  InstallmentSourceType sourceType, {
  required AccountProfileKind accountKind,
}) {
  return switch (sourceType) {
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.purchase => '消费分期',
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
