import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../credit/presentation/bill_status_presentation.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';

class CalendarBillRowPresentation {
  const CalendarBillRowPresentation({
    required this.billId,
    required this.accountName,
    required this.supportingTexts,
    required this.amount,
    required this.showBillIcon,
  });

  final String billId;
  final String accountName;
  final List<String> supportingTexts;
  final Money amount;
  final bool showBillIcon;
}

List<CalendarBillRowPresentation> buildCalendarDayBillRows({
  required DateTime date,
  required List<CreditDueCalendarItemReadModel> items,
  required AccountLookup accountLookup,
}) {
  return [
    for (final item in items)
      if (isSameDate(item.dueDate, date))
        CalendarBillRowPresentation(
          billId: item.billId,
          accountName: accountLookup.find(item.accountId)?.name ?? '未知账户',
          supportingTexts: [
            switch (item.itemType) {
              BillItemType.consumption => '消费明细',
              BillItemType.installment => '分期明细',
            },
          ],
          amount: item.pendingTotal,
          showBillIcon: true,
        ),
  ];
}

List<CalendarBillRowPresentation> buildCalendarMonthBillRows({
  required List<MonthlyBillSummaryReadModel> bills,
  required AccountLookup accountLookup,
}) {
  return [
    for (final bill in bills)
      CalendarBillRowPresentation(
        billId: bill.billId,
        accountName: accountLookup.find(bill.accountId)?.name ?? '未知账户',
        supportingTexts: [
          '${bill.itemCount} 条明细',
          billStatusLabel(bill.status),
        ],
        amount:
            bill.status == BillStatus.settled
                ? bill.expectedPrincipal +
                    bill.expectedInterest +
                    bill.expectedFee
                : bill.pendingTotal,
        showBillIcon: false,
      ),
  ];
}
