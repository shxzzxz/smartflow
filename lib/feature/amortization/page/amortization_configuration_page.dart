import 'package:flutter/material.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../presentation/amortization_configuration_draft.dart';

class AmortizationConfigurationPage extends StatefulWidget {
  const AmortizationConfigurationPage({
    required this.initialConfiguration,
    super.key,
  });

  final AmortizationConfigurationDraft initialConfiguration;

  @override
  State<AmortizationConfigurationPage> createState() =>
      _AmortizationConfigurationPageState();
}

class _AmortizationConfigurationPageState
    extends State<AmortizationConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _intervalController;
  late final TextEditingController _countController;
  late DateTime _firstRecognitionAt;
  late AmortizationCadenceUnit _cadenceUnit;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConfiguration;
    _firstRecognitionAt = initial.firstRecognitionAt;
    _cadenceUnit = initial.cadenceUnit;
    _intervalController = TextEditingController(
      text: '${initial.cadenceInterval}',
    );
    _countController = TextEditingController(
      text: '${initial.recognitionCount}',
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '摊销配置',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space12,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  children: [
                    AppFormSection(
                      title: '确认安排',
                      children: [
                        DateTimePlainFormRow(
                          label: '首期日期',
                          dateTime: _firstRecognitionAt,
                          value: _formatDate(_firstRecognitionAt),
                          onTap: (onSelected) =>
                              _pickDate(onSelected: onSelected),
                          onChanged: (_) {},
                          showChevron: true,
                        ),
                        AppPlainSegmentedFormRow<AmortizationCadenceUnit>(
                          label: '间隔方式',
                          value: _cadenceUnit,
                          segments: const [
                            AppSegment(
                              value: AmortizationCadenceUnit.daily,
                              label: '天',
                            ),
                            AppSegment(
                              value: AmortizationCadenceUnit.monthly,
                              label: '月',
                            ),
                            AppSegment(
                              value: AmortizationCadenceUnit.yearly,
                              label: '年',
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _cadenceUnit = value);
                          },
                        ),
                        AppPlainIntegerFormRow(
                          label: '间隔',
                          controller: _intervalController,
                          hintText: '请输入间隔',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                        AppPlainIntegerFormRow(
                          label: '期数',
                          controller: _countController,
                          hintText: '请输入确认期数',
                          requiredIndicator: true,
                          validator: _positiveIntegerValidator,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(label: '使用此配置', onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required ValueChanged<DateTime?> onSelected}) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _firstRecognitionAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _firstRecognitionAt = selected);
    onSelected(selected);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final interval = int.parse(_intervalController.text);
    final count = int.parse(_countController.text);
    Navigator.of(context).pop(
      AmortizationConfigurationDraft(
        firstRecognitionAt: _firstRecognitionAt,
        cadenceUnit: _cadenceUnit,
        cadenceInterval: interval,
        recognitionCount: count,
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _positiveIntegerValidator(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed <= 0 ? '请输入正整数' : null;
}
