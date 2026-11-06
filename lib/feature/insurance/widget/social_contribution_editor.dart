import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../widget/business/finance/money_input.dart';
import '../presentation/insurance_presentation.dart';

class SocialContributionEditorDialog extends StatefulWidget {
  const SocialContributionEditorDialog({super.key, this.existing});

  final SocialContributionRecord? existing;

  @override
  State<SocialContributionEditorDialog> createState() =>
      _SocialContributionEditorDialogState();
}

class _SocialContributionEditorDialogState
    extends State<SocialContributionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseController;
  late DateTime _month;
  String? _monthError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _month = existing?.month.start ?? DateTime.now();
    _baseController = TextEditingController(
      text: insuranceMoneyInputText(existing?.contributionBase),
    );
  }

  @override
  void dispose() {
    _baseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加缴费记录' : '编辑缴费记录'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPlainValueRow(
                label: '缴费年月',
                value: insuranceMonthLabel(MonthKey.fromDate(_month)),
                onTap: _pickMonth,
              ),
              if (_monthError case final error?)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.space4,
                    left: AppSpacing.space8,
                  ),
                  child: Text(
                    error,
                    style: context.appTextStyles.formSupporting.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              MoneyPlainFormRow(
                label: '缴费基数',
                controller: _baseController,
                hintText: '请输入缴费基数',
                requiredIndicator: true,
                validator: validateNonNegativeMoneyText,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('确定')),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: _month,
      firstYear: 1900,
      lastYear: 2100,
      title: '选择缴费年月',
    );
    if (selected == null) return;
    setState(() {
      _month = selected;
      _monthError = null;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final base = Money.tryParse(_baseController.text.trim());
    if (base == null) {
      setState(() => _monthError = '请输入有效的缴费基数');
      return;
    }
    Navigator.of(context).pop(
      SocialContributionDraft(
        month: MonthKey.fromDate(_month),
        contributionBase: base,
      ),
    );
  }
}

class SocialContributionDraft {
  const SocialContributionDraft({
    required this.month,
    required this.contributionBase,
  });

  final MonthKey month;
  final Money contributionBase;
}
