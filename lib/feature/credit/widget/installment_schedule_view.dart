import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_status_badge.dart';
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
        vertical: AppSpacing.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('第${item.periodNo}期', style: styles.formLabel),
              Text(formatDateLabel(item.date), style: styles.formLabel),
              if (item.recalculated)
                AppStatusBadge(label: '重算', color: colors.primary),
              if (item.status case final status?)
                AppStatusBadge(
                  label: installmentScheduleStatusLabel(status),
                  color: switch (status) {
                    InstallmentScheduleStatus.pending => colors.primary,
                    InstallmentScheduleStatus.partiallyPaid => colors.error,
                    InstallmentScheduleStatus.paid => colors.tertiary,
                    InstallmentScheduleStatus.skipped => colors.outline,
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Wrap(
            spacing: AppSpacing.space12,
            runSpacing: AppSpacing.space4,
            children: [
              Text('本金 ${item.principal.format()}', style: supporting),
              if (item.interest.minorUnits != 0)
                Text('利息 ${item.interest.format()}', style: supporting),
              if (item.fee.minorUnits != 0)
                Text('手续费 ${item.fee.format()}', style: supporting),
              Text(
                '合计 ${item.total.format()}',
                style: styles.formValueEmphasis,
              ),
              if (item.remainingPrincipal case final remaining?)
                Text('剩余 ${remaining.format()}', style: supporting),
            ],
          ),
        ],
      ),
    );
  }
}
