import 'package:flutter/material.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/design_system/token/typography.dart';
import 'package:smartflow/design_system/token/spacing.dart';

class AdaptiveMoneyText extends StatelessWidget {
  const AdaptiveMoneyText({
    required this.preciseText,
    required this.compactText,
    required this.style,
    required this.maxWidth,
    super.key,
    this.fallbackStyle,
    this.textAlign = TextAlign.end,
  });

  final String preciseText;
  final String compactText;
  final TextStyle style;
  final TextStyle? fallbackStyle;
  final double maxWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final smallerStyle =
        fallbackStyle ?? style.copyWith(fontSize: AppTypography.fontSizeSm);
    final candidates = [
      (text: preciseText, style: style),
      (text: preciseText, style: smallerStyle),
      (text: compactText, style: style),
      (text: compactText, style: smallerStyle),
    ];
    final selected = candidates.firstWhere(
      (candidate) => _fits(context, candidate.text, candidate.style),
      orElse: () => candidates.last,
    );

    return Text(
      selected.text,
      style: selected.style,
      maxLines: 1,
      textAlign: textAlign,
      overflow: TextOverflow.clip,
    );
  }

  bool _fits(BuildContext context, String text, TextStyle textStyle) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width <= maxWidth;
  }
}

class ComparedMoneyText extends StatelessWidget {
  const ComparedMoneyText({
    required this.originalPreciseText,
    required this.originalCompactText,
    required this.actualPreciseText,
    required this.actualCompactText,
    required this.originalStyle,
    required this.actualStyle,
    required this.maxWidth,
    super.key,
  });

  final String originalPreciseText;
  final String originalCompactText;
  final String actualPreciseText;
  final String actualCompactText;
  final TextStyle originalStyle;
  final TextStyle actualStyle;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final candidates = [
      (original: originalPreciseText, actual: actualPreciseText),
      (original: originalCompactText, actual: actualPreciseText),
      (original: originalCompactText, actual: actualCompactText),
    ];
    final selected = candidates.firstWhere(
      (candidate) => _fits(context, candidate.original, candidate.actual),
      orElse: () => candidates.last,
    );
    final shouldConstrain = !_fits(context, selected.original, selected.actual);

    Widget amountText(String text, TextStyle textStyle) => Text(
      text,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (shouldConstrain)
          Flexible(
            child: amountText(
              selected.original,
              originalStyle.copyWith(decoration: TextDecoration.lineThrough),
            ),
          )
        else
          amountText(
            selected.original,
            originalStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        const SizedBox(width: AppSpacing.space4),
        if (shouldConstrain)
          Flexible(child: amountText(selected.actual, actualStyle))
        else
          amountText(selected.actual, actualStyle),
      ],
    );
  }

  bool _fits(BuildContext context, String original, String actual) {
    return _measure(context, original, originalStyle) +
            AppSpacing.space4 +
            _measure(context, actual, actualStyle) <=
        maxWidth;
  }

  double _measure(BuildContext context, String text, TextStyle textStyle) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

class SummaryMoneyText extends StatelessWidget {
  const SummaryMoneyText({
    required this.money,
    required this.style,
    required this.maxWidth,
    super.key,
  });

  final Money money;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AdaptiveMoneyText(
      preciseText: formatMoney(money, style: MoneyFormatStyle.plain),
      compactText: formatMoney(money, style: MoneyFormatStyle.compact),
      style: style,
      maxWidth: maxWidth,
      textAlign: TextAlign.start,
    );
  }
}

class SectionMoneyText extends StatelessWidget {
  const SectionMoneyText({required this.money, required this.style, super.key});

  final Money money;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final absoluteMajor = money.minorUnits.abs() ~/ 100;
    final useCompact = absoluteMajor.toString().length > 6;
    return Text(
      formatMoney(
        money,
        style: useCompact ? MoneyFormatStyle.compact : MoneyFormatStyle.plain,
      ),
      style: style,
      maxLines: 1,
      textAlign: TextAlign.end,
    );
  }
}
