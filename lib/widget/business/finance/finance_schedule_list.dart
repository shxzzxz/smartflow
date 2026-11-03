import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

enum FinanceScheduleTone { info, success, warning, neutral }

class FinanceScheduleItem {
  const FinanceScheduleItem({
    required this.id,
    required this.periodLabel,
    required this.date,
    required this.amountLabel,
    this.statusLabel,
    this.statusTone,
    this.stageLabel,
    this.detailsLabel,
    this.onTap,
  });

  final String id;
  final String periodLabel;
  final DateTime date;
  final String amountLabel;
  final String? statusLabel;
  final FinanceScheduleTone? statusTone;
  final String? stageLabel;
  final String? detailsLabel;
  final VoidCallback? onTap;
}

class FinanceScheduleList extends StatelessWidget {
  const FinanceScheduleList({
    required this.items,
    this.rowWrapper,
    this.emptyMessage = '暂无计划',
    super.key,
  });

  final List<FinanceScheduleItem> items;
  final Widget Function(BuildContext, FinanceScheduleItem, Widget)? rowWrapper;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Text(emptyMessage),
          ),
        for (var index = 0; index < items.length; index++) ...[
          if (items[index].stageLabel case final label?)
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
            key: ValueKey(items[index].id),
            child:
                rowWrapper?.call(
                  context,
                  items[index],
                  _ScheduleRow(item: items[index]),
                ) ??
                _ScheduleRow(item: items[index]),
          ),
        ],
      ],
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});

  final FinanceScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final supporting = styles.listSupporting.copyWith(
      color: colors.onSurfaceVariant,
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 40,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                ),
                child: Text(
                  item.periodLabel,
                  style: styles.formLabel.copyWith(color: colors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateLabel(item.date), style: styles.formLabel),
                if (item.detailsLabel case final details?)
                  Text(details, style: supporting),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.amountLabel,
                  style: styles.formLabel,
                  textAlign: TextAlign.right,
                ),
                if (item.statusLabel case final status?)
                  Text(
                    status,
                    style: supporting.copyWith(
                      color: switch (item.statusTone) {
                        FinanceScheduleTone.info => colors.primary,
                        FinanceScheduleTone.success => financeColors.success,
                        FinanceScheduleTone.warning => financeColors.warning,
                        FinanceScheduleTone.neutral || _ => colors.outline,
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (item.onTap != null) ...[
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: AppSpacing.space16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    final onTap = item.onTap;
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
