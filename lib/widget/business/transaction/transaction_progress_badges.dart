import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/token/transaction.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';

import '../finance/finance_tone_color.dart';
import '../finance/finance_tone.dart';

class TransactionProgressBadges extends StatelessWidget {
  const TransactionProgressBadges({required this.badges, super.key});

  final List<TransactionBadgePresentation> badges;

  static const _wideSlotCount = 4;
  static const _narrowSlotCount = 3;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotCount =
            constraints.maxWidth >= AppTransactionTokens.wideBadgeMinWidth
                ? _wideSlotCount
                : _narrowSlotCount;
        final visibleBadges =
            badges.length <= slotCount
                ? badges
                : [
                  ...badges.take(slotCount - 1),
                  TransactionBadgePresentation(
                    label: '+${badges.length - slotCount + 1}',
                    tone: FinanceTone.neutral,
                  ),
                ];

        return Row(
          children: [
            for (var i = 0; i < visibleBadges.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.space2),
              Flexible(child: _BadgeChip(badge: visibleBadges[i])),
            ],
          ],
        );
      },
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

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppTransactionTokens.badgeMaxWidth,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        child: Text(
          badge.label,
          style: context.appTextStyles.transactionBadge.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}
