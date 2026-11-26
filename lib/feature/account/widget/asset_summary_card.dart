import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../widget/business/finance/adaptive_money_text.dart';

class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({
    required this.statistics,
    required this.hideBalances,
    super.key,
  });
  final AssetViewStatistics statistics;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final asset = statistics.assets.minorUnits;
    final liability = statistics.liabilities.minorUnits;
    final total = (asset.abs() + liability.abs()).clamp(1, 1 << 62);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        gradient: LinearGradient(
          colors: [colors.primary.withValues(alpha: 0.92), colors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.24),
            blurRadius: AppSpacing.space20,
            offset: const Offset(0, AppSpacing.space10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < AppSpacing.space48 * 6 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final overview = _overview(context);
            final legends = _legends(context);
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  overview,
                  const SizedBox(height: AppSpacing.space16),
                  legends,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: overview),
                const SizedBox(width: AppSpacing.space8),
                SizedBox(
                  width: AppSpacing.space48 * 3,
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: AppSpacing.space40 * 2,
                        child: CustomPaint(
                          painter: _AssetDonutPainter(
                            assetRatio: asset.abs() / total,
                            liabilityRatio: liability.abs() / total,
                            baseColor: colors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space10),
                      legends,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('净资产（元）', style: styles.onPrimaryLabel),
            const SizedBox(width: AppSpacing.space6),
            Icon(
              RemixIcons.eye_line,
              size: AppSpacing.space16,
              color: colors.onPrimary.withValues(alpha: 0.8),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space14),
        LayoutBuilder(
          builder: (context, constraints) => AdaptiveMoneyText(
            preciseText: hideBalances
                ? '¥ **,***.**'
                : _formatMoney(statistics.netAssets.minorUnits),
            compactText: hideBalances
                ? '¥ **,***.**'
                : formatMoney(
                    statistics.netAssets,
                    style: MoneyFormatStyle.compact,
                  ),
            style: styles.amountDisplay.copyWith(color: colors.onPrimary),
            maxWidth: constraints.maxWidth,
            textAlign: TextAlign.start,
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        Text(
          hideBalances ? '较上月 ****' : _formatNetAssetComparison(statistics),
          style: styles.onPrimarySupporting,
        ),
      ],
    );
  }

  Widget _legends(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Column(
      children: [
        _LegendRow(
          key: const ValueKey('asset-balance-legend'),
          label: '资产',
          money: statistics.assets,
          hideBalance: hideBalances,
          color: color.withValues(alpha: 0.72),
        ),
        const SizedBox(height: AppSpacing.space6),
        _LegendRow(
          key: const ValueKey('liability-balance-legend'),
          label: '负债',
          money: statistics.liabilities,
          hideBalance: hideBalances,
          color: color.withValues(alpha: 0.42),
        ),
      ],
    );
  }
}

class _AssetDonutPainter extends CustomPainter {
  const _AssetDonutPainter({
    required this.assetRatio,
    required this.liabilityRatio,
    required this.baseColor,
  });

  final double assetRatio;
  final double liabilityRatio;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    paint.color = baseColor.withValues(alpha: 0.22);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 6.283, false, paint);
    paint.color = baseColor.withValues(alpha: 0.72);
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.57,
      6.283 * assetRatio,
      false,
      paint,
    );
    paint.color = baseColor.withValues(alpha: 0.42);
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.57 + 6.283 * assetRatio,
      6.283 * liabilityRatio,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AssetDonutPainter oldDelegate) {
    return oldDelegate.assetRatio != assetRatio ||
        oldDelegate.liabilityRatio != liabilityRatio ||
        oldDelegate.baseColor != baseColor;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.money,
    required this.hideBalance,
    required this.color,
    super.key,
  });

  final String label;
  final Money money;
  final bool hideBalance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.space6),
        Expanded(flex: 1, child: Text(label, style: textStyles.onPrimaryTiny)),
        const SizedBox(width: AppSpacing.space4),
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hiddenText = '¥ ****';
              return AdaptiveMoneyText(
                preciseText: hideBalance ? hiddenText : money.format(),
                compactText: hideBalance
                    ? hiddenText
                    : formatMoney(money, style: MoneyFormatStyle.compact),
                style: textStyles.onPrimaryTinyStrong,
                maxWidth: constraints.maxWidth,
              );
            },
          ),
        ),
      ],
    );
  }
}

String _formatMoney(int minor) {
  final money = Money(minorUnits: minor);
  return money.format();
}

String _formatSignedMoney(int minor) {
  final sign = minor >= 0 ? '+' : '-';
  return '$sign¥${Money(minorUnits: minor.abs()).format()}';
}

String _formatNetAssetComparison(AssetViewStatistics change) {
  final delta = _formatSignedMoney(change.netAssetChange.minorUnits);
  final ratio = change.netAssetChangeRatio;
  if (change.netAssetChange.minorUnits == 0) {
    return '与上月持平';
  }
  if (change.isNewNetAssetValue || ratio == null) {
    return '较上月 $delta';
  }
  final sign = ratio >= 0 ? '+' : '-';
  return '较上月 $delta ($sign${(ratio.abs() * 100).toStringAsFixed(2)}%)';
}
