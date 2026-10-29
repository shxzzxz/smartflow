import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_supporting_items.dart';
import '../../../widget/business/finance/bill_item_row.dart';

String billItemLabel(BillItemReadModel item) {
  if (item.itemType == BillItemType.consumption) return '消费';
  return switch (item.installmentSourceType) {
    null => '分期',
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.purchase => '消费分期',
    InstallmentSourceType.disbursement =>
      item.accountKind == CreditLiabilityAccountKind.credit ? '现金分期' : '贷款分期',
  };
}

String? billItemDestination(BillItemReadModel item) {
  if (item.itemType != BillItemType.installment) return null;
  final contractId = item.contractId;
  return contractId == null ? null : '/installments/$contractId';
}

AppStatusBadgePresentation billItemStatusPresentation({
  required BillItemStatus status,
  required bool isOverdue,
}) {
  if (isOverdue) {
    return const AppStatusBadgePresentation(
      label: '已逾期',
      tone: AppStatusTone.danger,
    );
  }
  return switch (status) {
    BillItemStatus.pending => const AppStatusBadgePresentation(
      label: '待还',
      tone: AppStatusTone.warning,
    ),
    BillItemStatus.partiallyPaid => const AppStatusBadgePresentation(
      label: '部分已还',
      tone: AppStatusTone.warning,
    ),
    BillItemStatus.paid => const AppStatusBadgePresentation(
      label: '已核销',
      tone: AppStatusTone.success,
    ),
    BillItemStatus.overpaid => const AppStatusBadgePresentation(
      label: '溢缴',
      tone: AppStatusTone.primary,
    ),
    BillItemStatus.skipped => const AppStatusBadgePresentation(
      label: '已跳过',
      tone: AppStatusTone.neutral,
    ),
  };
}

BillItemRowPresentation billItemRowPresentation(BillItemReadModel item) {
  return BillItemRowPresentation(
    id: item.id,
    leadingIcon: item.itemType == BillItemType.consumption
        ? RemixIcons.shopping_bag_3_line
        : RemixIcons.calendar_schedule_line,
    title: billItemLabel(item),
    supportingTexts: [
      AppSupportingText('还款 ${formatDateLabel(item.repaymentDate)}'),
      if (item.itemType == BillItemType.consumption &&
          item.startInclusive != null &&
          item.endInclusive != null)
        AppSupportingText(
          '统计 ${formatDateLabel(item.startInclusive!)} - '
          '${formatDateLabel(item.endInclusive!)}',
        ),
    ],
    amount: item.remainingTotal,
    status: billItemStatusPresentation(
      status: item.status,
      isOverdue: item.isOverdue,
    ),
  );
}
