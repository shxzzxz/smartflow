import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/intake/intake_rules_api.dart';
import '../../../application/ledger/ledger_query_api.dart' show AccountType;
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../widget/business/account/account_picker_sheet.dart';
import '../../../widget/business/category/category_picker_sheet.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/recognition_rule_editor_view_model.dart';

class RecognitionRuleEditorPage extends ConsumerStatefulWidget {
  const RecognitionRuleEditorPage({
    this.ruleId,
    this.initialKind = RecognitionRuleKind.account,
    super.key,
  });
  final String? ruleId;
  final RecognitionRuleKind initialKind;
  @override
  ConsumerState<RecognitionRuleEditorPage> createState() =>
      _RecognitionRuleEditorPageState();
}

class _RecognitionRuleEditorPageState
    extends ConsumerState<RecognitionRuleEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _keywords = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final rule = await ref
        .read(recognitionRuleEditorViewModelProvider.notifier)
        .initialize(ruleId: widget.ruleId, kind: widget.initialKind);
    if (mounted && rule != null) _keywords.text = rule.keywords.join('\n');
  }

  @override
  void dispose() {
    _keywords.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final outcome = await ref
        .read(recognitionRuleEditorViewModelProvider.notifier)
        .save();
    if (mounted && outcome is SubmitSuccess) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recognitionRuleEditorViewModelProvider);
    final vm = ref.read(recognitionRuleEditorViewModelProvider.notifier);
    final rule = state.rule;
    final enabled = !state.loading && !state.saving;
    final target = state.targets
        .where((target) => target.id == rule?.targetAccountId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: widget.ruleId == null ? '新增识别规则' : '编辑识别规则'),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : rule == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error?.message ?? '规则加载失败'),
                          TextButton(onPressed: _load, child: const Text('重试')),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.space16),
                        children: [
                          if (state.error case final error?) ...[
                            AppStatusBanner(
                              message: error.message,
                              tone: AppStatusBannerTone.warning,
                            ),
                            const SizedBox(height: AppSpacing.space12),
                          ],
                          AppFormSection(
                            title: rule.kind == RecognitionRuleKind.account
                                ? '账户规则'
                                : '分类规则',
                            children: [
                              AppPlainTextAreaFormRow(
                                label: '关键词',
                                controller: _keywords,
                                enabled: enabled,
                                requiredIndicator: true,
                                maxLength: 2000,
                                minLines: 3,
                                maxLines: 5,
                                hintText: '每行一个关键词，或用逗号分隔',
                                supportingText: '识别文本包含任一关键词时命中。',
                                validator: (_) =>
                                    rule.keywords.isEmpty ? '请输入至少一个关键词' : null,
                                onChanged: vm.setKeywords,
                              ),
                              AppPlainSelectFormRow<String>(
                                label: rule.kind == RecognitionRuleKind.account
                                    ? '目标账户'
                                    : '目标分类',
                                value: rule.targetAccountId,
                                valueText: target?.displayName ?? '目标已不可用',
                                placeholder: rule.targetPath.isEmpty
                                    ? '请选择'
                                    : '目标已不可用，请重新选择',
                                enabled: enabled,
                                requiredIndicator: true,
                                validator: (id) =>
                                    id != null &&
                                        state.availableTargets.any(
                                          (t) => t.id == id,
                                        )
                                    ? null
                                    : '请选择可用的目标',
                                onChanged: (id) {
                                  if (id != null) vm.setTarget(id);
                                },
                                onTap: (onSelected) async {
                                  final id = await _pickTarget(state);
                                  if (mounted && id != null) onSelected(id);
                                },
                              ),
                              _SourceSelectRow(
                                value: rule.source == null
                                    ? 0
                                    : rule.source!.index + 1,
                                enabled: enabled,
                                onChanged: (value) => vm.setSource(
                                  value == 0
                                      ? null
                                      : RecognitionRuleSource.values[value - 1],
                                ),
                              ),
                              AppPlainSwitchRow(
                                label: '启用规则',
                                value: rule.enabled,
                                enabled: enabled,
                                onChanged: vm.setEnabled,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            if (rule != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: enabled ? _save : null,
                    child: Text(state.saving ? '保存中…' : '保存'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickTarget(RecognitionRuleEditorState state) {
    final rule = state.rule!;
    if (rule.kind == RecognitionRuleKind.account) {
      return showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => AccountPickerOptionsSheet(
          accounts: [
            for (final target in state.availableTargets)
              AccountPickerOption(
                id: target.id,
                name: target.displayName,
                iconKey: target.iconKey,
                profileKey: target.profileKey,
              ),
          ],
          selectedId: rule.targetAccountId,
          onAccountTap: (option) => Navigator.pop(context, option.id),
        ),
      );
    }
    return showCategoryPickerSheet(
      context: context,
      selectedId: rule.targetAccountId,
      sections: [
        for (final kind in [
          ImportCategoryKind.expense,
          ImportCategoryKind.income,
        ])
          CategoryPickerSection(
            type: kind == ImportCategoryKind.expense
                ? AccountType.expense
                : AccountType.income,
            label: kind == ImportCategoryKind.expense ? '支出分类' : '收入分类',
            nodes: [
              for (final root in state.availableTargets.where(
                (target) => target.parentId == null && target.direction == kind,
              ))
                CategoryPickerNode(
                  id: root.id,
                  label: root.name,
                  iconKey: root.iconKey,
                  children: [
                    for (final child in state.availableTargets.where(
                      (target) => target.parentId == root.id,
                    ))
                      CategoryPickerNode(
                        id: child.id,
                        label: child.name,
                        iconKey: child.iconKey,
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _SourceSelectRow extends StatelessWidget {
  const _SourceSelectRow({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => AppPlainFormRow(
    label: '适用来源',
    enabled: enabled,
    child: AppSelectMenu<int>(
      value: value,
      options: const [
        AppSelectOption(value: 0, label: '全部来源'),
        AppSelectOption(value: 1, label: '微信'),
        AppSelectOption(value: 2, label: '支付宝'),
      ],
      onChanged: onChanged,
      tooltip: '适用来源',
      triggerBuilder: (context, option) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppComponentTokens.controlMinHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(option.label, style: context.appTextStyles.formValue),
            ),
            const Icon(RemixIcons.arrow_right_s_line),
          ],
        ),
      ),
    ),
  );
}
