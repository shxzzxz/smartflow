import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/tokens/radius.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../application/accounting/accounting_api.dart';

/// 主交易行的"聚合 progress + 统计标记"badge 组。
///
/// 表达：退/报/利/费/优/差收/差支/不计统计/不计预算。
/// 金额为零的不显示；badge 保持单行展示。
class TransactionProgressBadges extends StatelessWidget {
  const TransactionProgressBadges({required this.item, super.key});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final badges = _resolveBadges(financeColors, item);
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

class _BadgeData {
  const _BadgeData({required this.label, required this.color});

  final String label;
  final Color color;
}

List<_BadgeData> _resolveBadges(
  AppThemeExtension financeColors,
  TransactionListItem item,
) {
  final badges = <_BadgeData>[];

  if (item.isExcludedFromStats) {
    badges.add(_BadgeData(label: '不计统计', color: financeColors.equity));
  }
  if (item.isExcludedFromBudget) {
    badges.add(_BadgeData(label: '不计预算', color: financeColors.equity));
  }
  if (item.refundedTotal != null) {
    badges.add(
      _BadgeData(
        label: '退 ${_format(item.refundedTotal!)}',
        color: financeColors.income,
      ),
    );
  }
  if (item.reimbursementReceivedTotal != null) {
    badges.add(
      _BadgeData(
        label: '报 ${_format(item.reimbursementReceivedTotal!)}',
        color: financeColors.info,
      ),
    );
  }
  final repaymentInterest = _detailAmount(
    item,
    TransactionDetailType.repaymentInterest,
  );
  if (repaymentInterest != null) {
    badges.add(
      _BadgeData(
        label: '利 ${_format(repaymentInterest)}',
        color: financeColors.expense,
      ),
    );
  }
  final repaymentFee = _detailAmount(item, TransactionDetailType.repaymentFee);
  if (repaymentFee != null) {
    badges.add(
      _BadgeData(
        label: '费 ${_format(repaymentFee)}',
        color: financeColors.expense,
      ),
    );
  }
  final repaymentDiscount = _detailAmount(
    item,
    TransactionDetailType.repaymentDiscount,
  );
  if (repaymentDiscount != null) {
    badges.add(
      _BadgeData(
        label: '优 ${_format(repaymentDiscount)}',
        color: financeColors.income,
      ),
    );
  }
  if (item.reimbursementGapIncome != null) {
    badges.add(
      _BadgeData(
        label: '差收 ${_format(item.reimbursementGapIncome!)}',
        color: financeColors.income,
      ),
    );
  }
  if (item.reimbursementGapExpense != null) {
    badges.add(
      _BadgeData(
        label: '差支 ${_format(item.reimbursementGapExpense!)}',
        color: financeColors.expense,
      ),
    );
  }

  return badges;
}

/// 从 details 中取指定 type 的金额(>0 才返回)。
Money? _detailAmount(TransactionListItem item, TransactionDetailType type) {
  for (final line in item.details) {
    if (line.type == type && line.amount.minorUnits > 0) {
      return line.amount;
    }
  }
  return null;
}

String _format(Money money) {
  final formatted = Money(minorUnits: money.minorUnits.abs()).format();
  final compact = formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  return compact.isEmpty ? '0' : compact;
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final _BadgeData badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: Text(
        badge.label,
        style: context.appTextStyles.badgeLabel.copyWith(color: badge.color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }
}
