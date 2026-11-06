import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_dropdown.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_select.dart';
import '../view_model/commercial_insurance_form_view_model.dart';

Future<InsuranceResponsibilityDraft?> showInsuranceResponsibilityEditor({
  required BuildContext context,
  required InsuranceResponsibilityDraft? existing,
  required String Function() newResponsibilityId,
  required String Function() newPointId,
}) {
  return showDialog<InsuranceResponsibilityDraft>(
    context: context,
    builder: (context) => _ResponsibilityEditorDialog(
      existing: existing,
      newResponsibilityId: newResponsibilityId,
      newPointId: newPointId,
    ),
  );
}

class _ResponsibilityEditorDialog extends StatefulWidget {
  const _ResponsibilityEditorDialog({
    required this.existing,
    required this.newResponsibilityId,
    required this.newPointId,
  });

  final InsuranceResponsibilityDraft? existing;
  final String Function() newResponsibilityId;
  final String Function() newPointId;

  @override
  State<_ResponsibilityEditorDialog> createState() =>
      _ResponsibilityEditorDialogState();
}

class _ResponsibilityEditorDialogState
    extends State<_ResponsibilityEditorDialog> {
  late ResponsibilityKind _kind;
  late final TextEditingController _nameController;
  late final List<_PointEditor> _points;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? ResponsibilityKind.medical;
    _nameController = TextEditingController(
      text: existing?.kind == ResponsibilityKind.custom ? existing!.name : '',
    );
    _points = [
      for (final point in existing?.points ?? const [])
        _PointEditor(
          id: point.id,
          label: TextEditingController(text: point.label),
          value: TextEditingController(text: point.value),
        ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增保障责任' : '编辑保障责任'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
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
              if (_kind == ResponsibilityKind.custom)
                AppPlainTextFormRow(
                  label: '责任名称',
                  controller: _nameController,
                  hintText: '例如：长期护理',
                  onChanged: (_) => setState(() => _error = null),
                ),
              const SizedBox(height: AppSpacing.space12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '责任要点',
                      style: context.appTextStyles.groupTitle,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPoint,
                    icon: const Icon(
                      RemixIcons.add_line,
                      size: AppSpacing.space16,
                    ),
                    label: const Text('添加要点'),
                  ),
                ],
              ),
              if (_points.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space12,
                  ),
                  child: Text(
                    '可暂不填写，之后继续补充。',
                    style: context.appTextStyles.listSupporting,
                  ),
                )
              else
                for (var index = 0; index < _points.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.space12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space10,
                          AppSpacing.space8,
                          AppSpacing.space4,
                          AppSpacing.space8,
                        ),
                        child: Column(
                          children: [
                            AppPlainTextFormRow(
                              label: '要点标签',
                              controller: _points[index].label,
                              hintText: '例如：住院医疗',
                              onChanged: (_) => setState(() => _error = null),
                            ),
                            AppPlainTextFormRow(
                              label: '要点内容',
                              controller: _points[index].value,
                              hintText: '例如：年度限额 20 万',
                              onChanged: (_) => setState(() => _error = null),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _removePoint(index),
                                icon: const Icon(
                                  RemixIcons.delete_bin_line,
                                  size: AppSpacing.space16,
                                ),
                                label: const Text('删除要点'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space8),
                  child: Text(
                    error,
                    style: context.appTextStyles.formSupporting.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _addPoint() {
    setState(() {
      _points.add(
        _PointEditor(
          id: widget.newPointId(),
          label: TextEditingController(),
          value: TextEditingController(),
        ),
      );
    });
  }

  void _removePoint(int index) {
    final point = _points.removeAt(index);
    point.dispose();
    setState(() => _error = null);
  }

  void _save() {
    final customName = _nameController.text.trim();
    if (_kind == ResponsibilityKind.custom && customName.isEmpty) {
      setState(() => _error = '请输入自定义责任名称');
      return;
    }
    final labels = <String>{};
    final points = <InsurancePointDraft>[];
    for (final point in _points) {
      final label = point.label.text.trim();
      final value = point.value.text.trim();
      if (label.isEmpty || value.isEmpty) {
        setState(() => _error = '责任要点的标签和内容都不能为空');
        return;
      }
      if (!labels.add(label)) {
        setState(() => _error = '同一责任项内的要点标签不能重复');
        return;
      }
      points.add(InsurancePointDraft(id: point.id, label: label, value: value));
    }
    Navigator.of(context).pop(
      InsuranceResponsibilityDraft(
        id: widget.existing?.id ?? widget.newResponsibilityId(),
        kind: _kind,
        name: _kind == ResponsibilityKind.custom
            ? customName
            : _kind.controlledName,
        points: points,
      ),
    );
  }
}

class _PointEditor {
  _PointEditor({required this.id, required this.label, required this.value});

  final String id;
  final TextEditingController label;
  final TextEditingController value;

  void dispose() {
    label.dispose();
    value.dispose();
  }
}
