import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_dropdown.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_select.dart';
import '../view_model/commercial_insurance_responsibilities_view_model.dart';

Future<InsuranceResponsibilityDraft?> showInsuranceResponsibilityEditor({
  required BuildContext context,
  required InsuranceResponsibilityDraft? existing,
  required String Function() newResponsibilityId,
}) {
  return showDialog<InsuranceResponsibilityDraft>(
    context: context,
    builder: (context) => _ResponsibilityEditorDialog(
      existing: existing,
      newResponsibilityId: newResponsibilityId,
    ),
  );
}

Future<InsurancePointDraft?> showInsurancePointEditor({
  required BuildContext context,
  required InsurancePointDraft? existing,
  required Set<String> existingLabels,
  required String Function() newPointId,
}) {
  return showDialog<InsurancePointDraft>(
    context: context,
    builder: (context) => _InsurancePointEditorDialog(
      existing: existing,
      existingLabels: existingLabels,
      newPointId: newPointId,
    ),
  );
}

class _ResponsibilityEditorDialog extends StatefulWidget {
  const _ResponsibilityEditorDialog({
    required this.existing,
    required this.newResponsibilityId,
  });

  final InsuranceResponsibilityDraft? existing;
  final String Function() newResponsibilityId;

  @override
  State<_ResponsibilityEditorDialog> createState() =>
      _ResponsibilityEditorDialogState();
}

class _ResponsibilityEditorDialogState
    extends State<_ResponsibilityEditorDialog> {
  late ResponsibilityKind _kind;
  late final TextEditingController _nameController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? ResponsibilityKind.medical;
    _nameController = TextEditingController(text: existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增卡片' : '编辑卡片'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainFormRow(
              label: '责任类型',
              child: AppDropdown<ResponsibilityKind>(
                value: _kind,
                tooltip: '选择责任类型',
                options: [
                  for (final kind in ResponsibilityKind.values)
                    AppSelectOption(value: kind, label: kind.label),
                ],
                onChanged: (value) => setState(() {
                  _kind = value;
                  _error = null;
                }),
              ),
            ),
            AppPlainTextFormRow(
              label: '责任名称',
              controller: _nameController,
              hintText: '例如：一般医疗、重大医疗、质子重离子医疗',
              requiredIndicator: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error case final error?)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space8),
                  child: Text(
                    error,
                    style: context.appTextStyles.formSupporting.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入责任名称');
      return;
    }
    Navigator.of(context).pop(
      InsuranceResponsibilityDraft(
        id: widget.existing?.id ?? widget.newResponsibilityId(),
        kind: _kind,
        name: name,
        points: widget.existing?.points ?? const [],
      ),
    );
  }
}

class _InsurancePointEditorDialog extends StatefulWidget {
  const _InsurancePointEditorDialog({
    required this.existing,
    required this.existingLabels,
    required this.newPointId,
  });

  final InsurancePointDraft? existing;
  final Set<String> existingLabels;
  final String Function() newPointId;

  @override
  State<_InsurancePointEditorDialog> createState() =>
      _InsurancePointEditorDialogState();
}

class _InsurancePointEditorDialogState
    extends State<_InsurancePointEditorDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _valueController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label);
    _valueController = TextEditingController(text: widget.existing?.value);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增要点' : '编辑要点'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPlainTextFormRow(
              label: '要点标签',
              controller: _labelController,
              hintText: '例如：住院医疗',
              requiredIndicator: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            AppPlainTextFormRow(
              label: '要点内容',
              controller: _valueController,
              hintText: '例如：年度限额 20 万',
              requiredIndicator: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error case final error?)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space8),
                  child: Text(
                    error,
                    style: context.appTextStyles.formSupporting.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? '添加' : '保存'),
        ),
      ],
    );
  }

  void _save() {
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    if (label.isEmpty || value.isEmpty) {
      setState(() => _error = '要点标签和内容都不能为空');
      return;
    }
    if (widget.existingLabels.contains(label)) {
      setState(() => _error = '同一责任项内的要点标签不能重复');
      return;
    }
    Navigator.of(context).pop(
      InsurancePointDraft(
        id: widget.existing?.id ?? widget.newPointId(),
        label: label,
        value: value,
      ),
    );
  }
}
