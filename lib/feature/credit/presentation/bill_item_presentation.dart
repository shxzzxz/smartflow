import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../widget/business/finance/bill_item_row.dart';
import '../../../widget/business/finance/bill_status_badge.dart';

String billItemLabel(BillItemReadModel item) {
  if (item.itemType == BillItemType.consumption) return '消费';
  return switch (item.installmentSourceType) {
    null => '分期',
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.disbursement =>
      item.accountKind == CreditLiabilityAccountKind.credit ? '现金分期' : '贷款分期',
  };
}

String? billItemDestination(BillItemReadModel item) {
  if (item.itemType != BillItemType.installment) return null;
  final contractId = item.contractId;
  return contractId == null ? null : '/installments/$contractId';
}

BillStatusBadgePresentation billItemStatusPresentation({
  required BillItemStatus status,
  required bool isOverdue,
}) {
  if (isOverdue) {
    return const BillStatusBadgePresentation(
      label: '已逾期',
      tone: BillStatusTone.danger,
    );
  }
  return switch (status) {
    BillItemStatus.pending => const BillStatusBadgePresentation(
      label: '待还',
      tone: BillStatusTone.warning,
    ),
    BillItemStatus.partiallyPaid => const BillStatusBadgePresentation(
      label: '部分已还',
      tone: BillStatusTone.warning,
    ),
    BillItemStatus.paid => const BillStatusBadgePresentation(
      label: '已核销',
      tone: BillStatusTone.success,
    ),
    BillItemStatus.skipped => const BillStatusBadgePresentation(
      label: '已跳过',
      tone: BillStatusTone.neutral,
    ),
  };
}

BillItemRowPresentation billItemRowPresentation(BillItemReadModel item) {
  return BillItemRowPresentation(
    id: item.id,
    leadingIcon:
        item.itemType == BillItemType.consumption
            ? RemixIcons.shopping_bag_3_line
            : RemixIcons.calendar_schedule_line,
    title: billItemLabel(item),
    supportingTexts: [formatDateLabel(item.repaymentDate)],
    amount: item.remainingTotal,
    status: billItemStatusPresentation(
      status: item.status,
      isOverdue: item.isOverdue,
    ),
  );
}
