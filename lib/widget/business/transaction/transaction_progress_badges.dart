import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';

import '../finance/finance_tone_color.dart';

class TransactionProgressBadges extends StatelessWidget {
  const TransactionProgressBadges({required this.badges, super.key});

  final List<TransactionBadgePresentation> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < badges.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.space6),
            _BadgeChip(badge: badges[i]),
          ],
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final TransactionBadgePresentation badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final color = financeToneColor(colors, financeColors, badge.tone);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: Text(
        badge.label,
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }
}
