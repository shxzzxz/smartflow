import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../presentation/insurance_coverage_field.dart';

Future<String?> showInsuranceCoverageFieldEditor({
  required BuildContext context,
  required InsuranceCoverageField field,
  required String? value,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CoverageFieldEditor(field: field, value: value),
  );
}

class _CoverageFieldEditor extends StatefulWidget {
  const _CoverageFieldEditor({required this.field, required this.value});

  final InsuranceCoverageField field;
  final String? value;

  @override
  State<_CoverageFieldEditor> createState() => _CoverageFieldEditorState();
}

class _CoverageFieldEditorState extends State<_CoverageFieldEditor> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (inputKey, hintText) = switch (widget.field) {
      InsuranceCoverageField.summary => (
        'coverage-summary-input',
        '概括这份保单的保障范围',
      ),
      InsuranceCoverageField.highlights => (
        'coverage-highlights-input',
        '记录值得关注的保障特点，每行一条',
      ),
      InsuranceCoverageField.waitingPeriod => (
        'coverage-waiting-period-input',
        '例如30天，可补充不同责任的等待期约定',
      ),
      InsuranceCoverageField.exclusions => (
        'coverage-exclusions-input',
        '概述既往症约定、免责及除外事项',
      ),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space8,
          AppSpacing.space16,
          AppSpacing.space16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '编辑${widget.field.label}',
              style: context.appTextStyles.subsectionTitleStrong,
            ),
            const SizedBox(height: AppSpacing.space16),
            AppPlainTextAreaFormRow(
              key: ValueKey(inputKey),
              label: widget.field.label,
              controller: _controller,
              hintText: hintText,
              layout: AppPlainFormRowLayout.vertical,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.space24),
            AppSubmitButton(
              label: '保存',
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
