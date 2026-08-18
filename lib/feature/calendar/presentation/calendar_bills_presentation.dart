import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../widget/business/finance/bill_item_row.dart';
import '../../../widget/business/finance/bill_status_badge.dart';
import '../../../widget/business/finance/bill_summary_row.dart';

import '../../credit/presentation/bill_item_presentation.dart';
import '../../credit/presentation/bill_status_presentation.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';

sealed class CalendarBillRowPresentation {
  const CalendarBillRowPresentation();
}

final class CalendarBillDueRowPresentation extends CalendarBillRowPresentation {
  const CalendarBillDueRowPresentation({
    required this.billId,
    required this.presentation,
  });

  final String billId;
  final BillItemRowPresentation presentation;
}

final class CalendarBillSummaryRowPresentation
    extends CalendarBillRowPresentation {
  const CalendarBillSummaryRowPresentation({required this.summary});

  final BillSummaryRowPresentation summary;
}

List<CalendarBillRowPresentation> buildCalendarDayBillRows({
  required DateTime date,
  required List<CreditDueCalendarItemReadModel> items,
  required AccountLookup accountLookup,
}) {
  return [
    for (final item in items)
      if (isSameDate(item.dueDate, date))
        CalendarBillDueRowPresentation(
          billId: item.billId,
          presentation: BillItemRowPresentation(
            id: item.billItemId,
            leadingIcon: RemixIcons.bill_line,
            title: accountLookup.find(item.accountId)?.name ?? '未知账户',
            supportingTexts: [
              switch (item.itemType) {
                BillItemType.consumption => '消费明细',
                BillItemType.installment => '分期明细',
              },
            ],
            amount: item.pendingTotal,
            status: billItemStatusPresentation(
              status: item.status,
              isOverdue: item.isOverdue,
            ),
            showChevron: true,
          ),
        ),
  ];
}

List<CalendarBillRowPresentation> buildCalendarMonthBillRows({
  required List<MonthlyBillSummaryReadModel> bills,
  required AccountLookup accountLookup,
}) {
  return [
    for (final bill in bills)
      CalendarBillSummaryRowPresentation(
        summary: BillSummaryRowPresentation(
          id: bill.billId,
          title: accountLookup.find(bill.accountId)?.name ?? '未知账户',
          supportingTexts: [
            BillSummarySupportingText(text: '${bill.itemCount} 条明细'),
          ],
          amount:
              bill.status == BillStatus.settled
                  ? bill.expectedPrincipal +
                      bill.expectedInterest +
                      bill.expectedFee
                  : bill.pendingTotal,
          status: _billStatusPresentation(bill.status),
          showChevron: true,
        ),
      ),
  ];
}

BillStatusBadgePresentation _billStatusPresentation(BillStatus status) {
  return switch (status) {
    BillStatus.open => BillStatusBadgePresentation(
      label: billStatusLabel(BillStatus.open),
      tone: BillStatusTone.primary,
    ),
    BillStatus.billed => BillStatusBadgePresentation(
      label: billStatusLabel(BillStatus.billed),
      tone: BillStatusTone.warning,
    ),
    BillStatus.settled => BillStatusBadgePresentation(
      label: billStatusLabel(BillStatus.settled),
      tone: BillStatusTone.success,
    ),
  };
}
