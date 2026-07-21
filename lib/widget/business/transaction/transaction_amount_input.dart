import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/form.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';

class TransactionAmountInput extends StatelessWidget {
  const TransactionAmountInput({
    required this.amountController,
    required this.noteController,
    required this.semantic,
    required this.amountValidator,
    super.key,
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  final MoneySemantic semantic;
  final FormFieldValidator<String> amountValidator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>();
    final textStyles = context.appTextStyles;
    final amountColor = switch (semantic) {
      MoneySemantic.expense => financeColors?.expense ?? colors.onSurface,
      MoneySemantic.income => financeColors?.income ?? colors.onSurface,
      _ => colors.onSurface,
    };

    return AppSurface(
      borderRadius: AppRadius.radiusXl,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppFormTokens.rowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space14,
            vertical: AppSpacing.space8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final amountStyle = textStyles.amountHero.copyWith(
                color: amountColor,
              );
              final currencyStyle = textStyles.amountPrimary.copyWith(
                color: amountColor,
              );
              return ValueListenableBuilder(
                valueListenable: amountController,
                builder: (context, value, _) {
                  final layout = _amountInputLayout(
                    context: context,
                    text: value.text,
                    amountStyle: amountStyle,
                    currencyStyle: currencyStyle,
                    maxWidth: constraints.maxWidth,
                  );
                  return Row(
                    children: [
                      if (layout.showNote) ...[
                        Icon(
                          Icons.notes_rounded,
                          size: AppSpacing.space20,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        Expanded(
                          child: AppPlainTextFormField(
                            key: const ValueKey('transaction-note-input'),
                            controller: noteController,
                            maxLines: 1,
                            style: textStyles.inputText,
                            hintText: '添加备注',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space12),
                      ] else
                        const Spacer(),
                      Text('¥', style: currencyStyle),
                      const SizedBox(width: AppSpacing.space4),
                      SizedBox(
                        width: layout.amountWidth,
                        child: TextFormField(
                          key: const ValueKey('transaction-amount-input'),
                          controller: amountController,
                          readOnly: true,
                          showCursor: false,
                          textAlign: TextAlign.end,
                          inputFormatters: [moneyInputFormatter],
                          validator: amountValidator,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                          style: amountStyle,
                          decoration: appPlainInputDecoration(
                            context,
                            hintText: '0.00',
                          ).copyWith(
                            hintStyle: amountStyle.copyWith(
                              color: amountColor.withValues(
                                alpha: AppFormTokens.subduedOpacity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

({double amountWidth, bool showNote}) _amountInputLayout({
  required BuildContext context,
  required String text,
  required TextStyle amountStyle,
  required TextStyle currencyStyle,
  required double maxWidth,
}) {
  final desiredWidth =
      _textWidth(context, text, amountStyle) + AppSpacing.space4;
  final currencyWidth = _textWidth(context, '¥', currencyStyle);
  final maxAmountWidthWithNote =
      maxWidth -
      AppSpacing.space20 -
      AppSpacing.space8 -
      AppSpacing.space12 -
      AppFormTokens.rowMinHeight -
      currencyWidth -
      AppSpacing.space4;
  final showNote = desiredWidth <= maxAmountWidthWithNote;
  final maxAmountWidth =
      (maxWidth - currencyWidth - AppSpacing.space4)
          .clamp(0, maxWidth)
          .toDouble();
  final minAmountWidth =
      AppFormTokens.amountInputWidth.clamp(0, maxAmountWidth).toDouble();

  return (
    amountWidth: desiredWidth.clamp(minAmountWidth, maxAmountWidth).toDouble(),
    showNote: showNote,
  );
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}
