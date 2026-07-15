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
          child: Row(
            children: [
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
              Text(
                '¥',
                style: textStyles.amountPrimary.copyWith(color: amountColor),
              ),
              const SizedBox(width: AppSpacing.space4),
              SizedBox(
                width: AppFormTokens.amountInputWidth,
                child: TextFormField(
                  key: const ValueKey('transaction-amount-input'),
                  controller: amountController,
                  readOnly: true,
                  showCursor: false,
                  textAlign: TextAlign.end,
                  inputFormatters: [moneyInputFormatter],
                  validator: amountValidator,
                  style: textStyles.amountHero.copyWith(color: amountColor),
                  decoration: appPlainInputDecoration(
                    context,
                    hintText: '0.00',
                  ).copyWith(
                    hintStyle: textStyles.amountHero.copyWith(
                      color: amountColor.withValues(
                        alpha: AppFormTokens.subduedOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
