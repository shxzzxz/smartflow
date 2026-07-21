import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';

import '../finance/finance_tone_color.dart';
import '../finance/finance_tone.dart';

class TransactionProgressBadges extends StatelessWidget {
  const TransactionProgressBadges({required this.badges, super.key});

  final List<TransactionBadgePresentation> badges;

  static const _maxSlotCount = 4;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = context.appTextStyles.transactionBadge;
        final candidates = _buildCandidates();
        final visibleBadges = candidates.firstWhere(
          (candidate) =>
              _measureCandidate(context, candidate, style) <=
              constraints.maxWidth,
          orElse: () => candidates.last,
        );
        final shouldConstrain =
            _measureCandidate(context, visibleBadges, style) >
            constraints.maxWidth;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleBadges.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.space2),
              if (shouldConstrain)
                Flexible(child: _BadgeChip(badge: visibleBadges[i]))
              else
                _BadgeChip(badge: visibleBadges[i]),
            ],
          ],
        );
      },
    );
  }

  List<List<TransactionBadgePresentation>> _buildCandidates() {
    final candidates = <List<TransactionBadgePresentation>>[];

    if (badges.length <= _maxSlotCount) {
      candidates.add(badges);
    }

    final firstAggregateSlotCount = badges.length.clamp(2, _maxSlotCount);
    for (var slotCount = firstAggregateSlotCount; slotCount >= 2; slotCount--) {
      if (badges.length <= slotCount) continue;
      candidates.add([
        ...badges.take(slotCount - 1),
        TransactionBadgePresentation(
          label: '+${badges.length - slotCount + 1}',
          tone: FinanceTone.neutral,
        ),
      ]);
    }

    candidates.add(
      badges.length == 1
          ? [badges.first]
          : [
            TransactionBadgePresentation(
              label: '+${badges.length}',
              tone: FinanceTone.neutral,
            ),
          ],
    );
    return candidates;
  }

  double _measureCandidate(
    BuildContext context,
    List<TransactionBadgePresentation> candidate,
    TextStyle style,
  ) {
    final badgesWidth = candidate.fold<double>(
      0,
      (total, badge) => total + _measureBadge(context, badge.label, style),
    );
    return badgesWidth + AppSpacing.space2 * (candidate.length - 1);
  }

  double _measureBadge(BuildContext context, String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width + AppSpacing.space2 * 2;
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
    );
  }
}
