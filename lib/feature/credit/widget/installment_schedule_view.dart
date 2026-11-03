import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../widget/business/finance/finance_schedule_list.dart';
import '../presentation/installment_schedule_presentation.dart';

class InstallmentScheduleView extends StatelessWidget {
  const InstallmentScheduleView({
    required this.items,
    this.rowWrapper,
    super.key,
  });
  final List<InstallmentScheduleViewItem> items;
  final Widget Function(BuildContext, InstallmentScheduleViewItem, Widget)?
  rowWrapper;

  @override
  Widget build(BuildContext context) {
    final wrapper = rowWrapper;
    final itemsById = {for (final item in items) item.id: item};
    return FinanceScheduleList(
      emptyMessage: '暂无还款计划',
      items: [
        for (final item in items)
          FinanceScheduleItem(
            id: item.id,
            stageLabel: item.stageLabel,
            periodLabel:
                item.periodLabel ?? item.periodNo.toString().padLeft(2, '0'),
            date: item.date,
            detailsLabel:
                item.detailsLabel ??
                '本金 ${item.principal.format()}'
                    '${item.interest.minorUnits > 0 ? '  利息 ${item.interest.format()}' : ''}'
                    '${item.fee.minorUnits > 0 ? '  手续费 ${item.fee.format()}' : ''}',
            amountLabel: item.amountLabel ?? item.total.format(),
            statusLabel:
                item.statusLabel ??
                (item.status == null
                    ? null
                    : installmentScheduleStatusLabel(item.status!)),
            statusTone: _toneFor(item.status, custom: item.statusLabel != null),
          ),
      ],
      rowWrapper: wrapper == null
          ? null
          : (context, row, child) {
              return wrapper(context, itemsById[row.id]!, child);
            },
    );
  }
}

FinanceScheduleTone? _toneFor(
  InstallmentScheduleStatus? status, {
  required bool custom,
}) {
  if (status == null && !custom) return null;
  if (custom) return FinanceScheduleTone.info;
  return switch (status!) {
    InstallmentScheduleStatus.pending => FinanceScheduleTone.info,
    InstallmentScheduleStatus.partiallyPaid => FinanceScheduleTone.warning,
    InstallmentScheduleStatus.paid => FinanceScheduleTone.success,
    InstallmentScheduleStatus.skipped => FinanceScheduleTone.neutral,
  };
}
