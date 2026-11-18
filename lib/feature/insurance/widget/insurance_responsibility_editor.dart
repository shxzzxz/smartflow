import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../presentation/insurance_responsibility_suggestions.dart';
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
  required ResponsibilityKind responsibilityKind,
  required InsurancePointDraft? existing,
  required Set<String> existingLabels,
  required String Function() newPointId,
  VoidCallback? onDelete,
}) {
  return showDialog<InsurancePointDraft>(
    context: context,
    builder: (context) => _InsurancePointEditorDialog(
      responsibilityKind: responsibilityKind,
      existing: existing,
      existingLabels: {for (final label in existingLabels) label.trim()},
      newPointId: newPointId,
      onDelete: onDelete,
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
  late final TextEditingController _descriptionController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? ResponsibilityKind.medical;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增卡片' : '编辑卡片'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainChoiceChipFormRow<ResponsibilityKind>(
              key: const ValueKey('responsibility-kind-choice'),
              label: '责任类型',
              value: _kind,
              options: [
                for (final kind in ResponsibilityKind.values)
                  AppChoiceChipOption(value: kind, label: kind.label),
              ],
              onChanged: (value) => setState(() {
                _kind = value;
                _error = null;
              }),
            ),
            AppPlainTextFormRow(
              key: const ValueKey('responsibility-name'),
              label: '责任名称',
              controller: _nameController,
              hintText: '输入责任名称',
              requiredIndicator: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            _CommonNameSuggestions(
              key: const ValueKey('responsibility-common-names'),
              names: responsibilityNameSuggestions(_kind),
              selected: _nameController.text.trim(),
              onSelected: (name) => setState(() {
                _nameController.value = TextEditingValue(
                  text: name,
                  selection: TextSelection.collapsed(offset: name.length),
                );
                _error = null;
              }),
            ),
            AppPlainTextAreaFormRow(
              key: const ValueKey('responsibility-description'),
              label: '责任说明',
              controller: _descriptionController,
              hintText: '简要说明这项责任的保障范围',
              layout: AppPlainFormRowLayout.vertical,
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
    final description = _descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入责任名称');
      return;
    }
    Navigator.of(context).pop(
      InsuranceResponsibilityDraft(
        id: widget.existing?.id ?? widget.newResponsibilityId(),
        kind: _kind,
        name: name,
        description: description.isEmpty ? null : description,
        points: widget.existing?.points ?? const [],
      ),
    );
  }
}

class _InsurancePointEditorDialog extends StatefulWidget {
  const _InsurancePointEditorDialog({
    required this.responsibilityKind,
    required this.existing,
    required this.existingLabels,
    required this.newPointId,
    this.onDelete,
  });

  final ResponsibilityKind responsibilityKind;
  final InsurancePointDraft? existing;
  final Set<String> existingLabels;
  final String Function() newPointId;
  final VoidCallback? onDelete;

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
    final commonNames = responsibilityPointNameSuggestions(
      widget.responsibilityKind,
    ).where((name) => !widget.existingLabels.contains(name)).toList();
    return AlertDialog(
      title: Text(widget.existing == null ? '新增要点' : '编辑要点'),
      scrollable: true,
      actionsAlignment: widget.onDelete == null
          ? MainAxisAlignment.end
          : MainAxisAlignment.spaceBetween,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainTextFormRow(
              key: const ValueKey('responsibility-point-name'),
              label: '要点名称',
              controller: _labelController,
              hintText: '例如：住院医疗',
              requiredIndicator: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (commonNames.isNotEmpty)
              _CommonNameSuggestions(
                key: const ValueKey('responsibility-point-common-names'),
                names: commonNames,
                selected: _labelController.text.trim(),
                onSelected: (name) => setState(() {
                  _labelController.value = TextEditingValue(
                    text: name,
                    selection: TextSelection.collapsed(offset: name.length),
                  );
                  _error = null;
                }),
              ),
            AppPlainTextFormRow(
              key: const ValueKey('responsibility-point-value'),
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
        if (widget.onDelete case final onDelete?)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: AppSpacing.space8),
            FilledButton(
              onPressed: _save,
              child: Text(widget.existing == null ? '添加' : '保存'),
            ),
          ],
        ),
      ],
    );
  }

  void _save() {
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    if (label.isEmpty || value.isEmpty) {
      setState(() => _error = '要点名称和内容都不能为空');
      return;
    }
    if (widget.existingLabels.contains(label)) {
      setState(() => _error = '同一责任项内的要点名称不能重复');
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

class _CommonNameSuggestions extends StatelessWidget {
  const _CommonNameSuggestions({
    required this.names,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> names;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: AppChoiceChipGroup<String>(
        options: [
          for (final name in names)
            AppChoiceChipOption(value: name, label: name),
        ],
        selected: selected,
        size: AppChoiceChipSize.compact,
        onChanged: onSelected,
      ),
    );
  }
}
