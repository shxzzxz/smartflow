import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../../../design_system/widget/app_select.dart';
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
  late final _year = TextEditingController(
    text: (widget.existing?.year ?? DateTime.now().year).toString(),
  );
  late final _base = TextEditingController(
    text: insuranceMoneyInputText(widget.existing?.contributionBase),
  );
  late final _amount = TextEditingController(
    text: insuranceMoneyInputText(widget.existing?.contributionAmount),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late var _month = widget.existing?.month ?? 0;

  @override
  void dispose() {
    _year.dispose();
    _base.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加缴费记录' : '编辑缴费记录'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainIntegerFormRow(
              key: const ValueKey('contribution-year-input'),
              label: '缴费年份',
              hintText: '例如：2026',
              controller: _year,
              requiredIndicator: true,
              validator: (value) {
                final year = int.tryParse(value?.trim() ?? '');
                return year == null || year < 1900 || year > 2100
                    ? '请输入 1900 至 2100 年之间的年份'
                    : null;
              },
            ),
            AppPlainSelectMenuFormRow<int>(
              key: const ValueKey('contribution-month-input'),
              label: '缴费月份',
              value: _month,
              options: [
                const AppSelectOption(value: 0, label: '不填写'),
                for (var month = 1; month <= 12; month++)
                  AppSelectOption(value: month, label: '$month月'),
              ],
              onChanged: (value) => setState(() => _month = value),
            ),
            MoneyPlainFormRow(
              key: const ValueKey('contribution-base-input'),
              label: '缴费基数',
              controller: _base,
              hintText: '可选',
              validator: validateOptionalNonNegativeMoneyText,
            ),
            MoneyPlainFormRow(
              key: const ValueKey('contribution-amount-input'),
              label: '缴费金额',
              controller: _amount,
              hintText: '请输入缴费金额',
              requiredIndicator: true,
              validator: validateNonNegativeMoneyText,
            ),
            AppPlainTextAreaFormRow(
              key: const ValueKey('contribution-note-input'),
              label: '缴费说明',
              controller: _note,
              hintText: '可选',
              layout: AppPlainFormRowLayout.vertical,
            ),
          ],
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(
      SocialContributionDraft(
        year: int.parse(_year.text.trim()),
        month: _month == 0 ? null : _month,
        contributionBase: Money.tryParse(_base.text.trim()),
        contributionAmount: Money.tryParse(_amount.text.trim())!,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class SocialContributionDraft {
  const SocialContributionDraft({
    required this.year,
    this.month,
    this.contributionBase,
    required this.contributionAmount,
    this.note,
  });

  final int year;
  final int? month;
  final Money? contributionBase;
  final Money contributionAmount;
  final String? note;
}
