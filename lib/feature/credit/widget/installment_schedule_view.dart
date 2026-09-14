import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
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
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.space16),
            child: Text('暂无还款计划'),
          ),
        for (final item in items) ...[
          if (item.stageLabel case final label?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space12,
                AppSpacing.space12,
                AppSpacing.space12,
                AppSpacing.space4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: context.appTextStyles.listSupporting),
              ),
            ),
          KeyedSubtree(
            key: ValueKey(item.id),
            child:
                rowWrapper?.call(context, item, _ScheduleRow(item: item)) ??
                _ScheduleRow(item: item),
          ),
        ],
      ],
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});
  final InstallmentScheduleViewItem item;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final supporting = styles.listSupporting.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              item.periodLabel ?? '${item.periodNo}',
              style: styles.formLabel,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateLabel(item.date), style: styles.formLabel),
                Text(
                  item.detailsLabel ??
                      '本金 ${item.principal.format()}'
                          '${item.interest.minorUnits > 0 ? '  利息 ${item.interest.format()}' : ''}'
                          '${item.fee.minorUnits > 0 ? '  手续费 ${item.fee.format()}' : ''}',
                  style: supporting,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amountLabel ?? item.total.format(),
                style: styles.formLabel,
              ),
              if (item.statusLabel case final customStatus?)
                Text(
                  customStatus,
                  style: supporting.copyWith(color: colors.primary),
                )
              else if (item.status case final status?)
                Text(
                  installmentScheduleStatusLabel(status),
                  style: supporting.copyWith(
                    color: switch (status) {
                      InstallmentScheduleStatus.pending => colors.primary,
                      InstallmentScheduleStatus.partiallyPaid => colors.error,
                      InstallmentScheduleStatus.paid => colors.tertiary,
                      InstallmentScheduleStatus.skipped => colors.outline,
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
