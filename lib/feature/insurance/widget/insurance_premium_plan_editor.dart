import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_command_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../widget/business/finance/money_input.dart';
import '../presentation/insurance_presentation.dart';

class InsurancePremiumPlanDraft {
  const InsurancePremiumPlanDraft(this.plan);

  final PremiumPlan? plan;
}

class InsurancePremiumPlanEditorDialog extends StatefulWidget {
  const InsurancePremiumPlanEditorDialog({super.key, this.existing});

  final PremiumPlan? existing;

  @override
  State<InsurancePremiumPlanEditorDialog> createState() =>
      _InsurancePremiumPlanEditorDialogState();
}

class _InsurancePremiumPlanEditorDialogState
    extends State<InsurancePremiumPlanEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late var _frequency = widget.existing?.frequency ?? PremiumFrequency.other;
  late final _termCount = TextEditingController(
    text: widget.existing?.termCount?.toString() ?? '',
  );
  late final _amount = TextEditingController(
    text: insuranceMoneyInputText(widget.existing?.amount),
  );

  @override
  void dispose() {
    _termCount.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('缴费配置'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainChoiceChipFormRow<PremiumFrequency>(
              key: const ValueKey('commercial-premium-frequency-choice'),
              label: '缴费频率',
              value: _frequency,
              requiredIndicator: true,
              layout: AppChoiceChipLayout.wrap,
              options: [
                for (final frequency in PremiumFrequency.values)
                  AppChoiceChipOption(value: frequency, label: frequency.label),
              ],
              onChanged: (value) => setState(() => _frequency = value),
            ),
            AppPlainIntegerFormRow(
              key: const ValueKey('commercial-premium-term-count'),
              label: '缴费期数',
              controller: _termCount,
              hintText: '可选，例如：20',
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final count = int.tryParse(text);
                return count == null || count <= 0 ? '请输入正整数' : null;
              },
            ),
            MoneyPlainFormRow(
              key: const ValueKey('commercial-premium-amount'),
              label: '期缴金额',
              controller: _amount,
              hintText: '可选',
              validator: validateOptionalNonNegativeMoneyText,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const InsurancePremiumPlanDraft(null)),
            child: const Text('清除配置'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      InsurancePremiumPlanDraft(
        PremiumPlan(
          frequency: _frequency,
          termCount: int.tryParse(_termCount.text.trim()),
          amount: Money.tryParse(_amount.text.trim()),
        ),
      ),
    );
  }
}
