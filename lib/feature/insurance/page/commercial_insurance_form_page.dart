import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_form_view_model.dart';
import '../widget/insurance_responsibility_editor.dart';

class CommercialInsuranceFormPage extends ConsumerWidget {
  const CommercialInsuranceFormPage({
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final String? insuranceId;
  final String? initialInsuredPersonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = commercialInsuranceFormViewModelProvider(
      insuranceId,
      initialInsuredPersonId,
    );
    final state = ref.watch(provider);
    final title = insuranceId == null ? '新增商业保险' : '编辑商业保险';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (value) {
                  if (value == null) {
                    return const Center(child: Text('商业保险不存在'));
                  }
                  if (value.insuredPeople.isEmpty) {
                    return _NoInsuredPeople(
                      onAdd: () => _addInsuredPerson(context, ref, provider),
                    );
                  }
                  return _CommercialInsuranceFormContent(
                    key: ValueKey(
                      'commercial-insurance-${insuranceId ?? 'new'}',
                    ),
                    insuranceId: insuranceId,
                    initialInsuredPersonId: initialInsuredPersonId,
                    initialState: value,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addInsuredPerson(
    BuildContext context,
    WidgetRef ref,
    CommercialInsuranceFormViewModelProvider provider,
  ) async {
    await context.push('/insurance/members/new');
    if (context.mounted) ref.invalidate(provider);
  }
}

class _CommercialInsuranceFormContent extends ConsumerStatefulWidget {
  const _CommercialInsuranceFormContent({
    required this.initialState,
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final String? insuranceId;
  final String? initialInsuredPersonId;
  final CommercialInsuranceFormState initialState;

  @override
  ConsumerState<_CommercialInsuranceFormContent> createState() =>
      _CommercialInsuranceFormContentState();
}

class _CommercialInsuranceFormContentState
    extends ConsumerState<_CommercialInsuranceFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _insurerController;
  late final TextEditingController _productFormController;
  late final TextEditingController _coverageAmountController;
  late final TextEditingController _coverageAmountNoteController;
  late final TextEditingController _premiumAmountController;
  late final TextEditingController _premiumNoteController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialState.initialValues;
    _nameController = TextEditingController(text: initial.name);
    _insurerController = TextEditingController(text: initial.insurerName);
    _productFormController = TextEditingController(text: initial.productForm);
    _coverageAmountController = TextEditingController(
      text: initial.coverageAmount,
    );
    _coverageAmountNoteController = TextEditingController(
      text: initial.coverageAmountNote,
    );
    _premiumAmountController = TextEditingController(
      text: initial.premiumAmount,
    );
    _premiumNoteController = TextEditingController(text: initial.premiumNote);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _insurerController.dispose();
    _productFormController.dispose();
    _coverageAmountController.dispose();
    _coverageAmountNoteController.dispose();
    _premiumAmountController.dispose();
    _premiumNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.initialState;
    final provider = commercialInsuranceFormViewModelProvider(
      widget.insuranceId,
      widget.initialInsuredPersonId,
    );
    final notifier = ref.read(provider.notifier);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space8,
          AppSpacing.space16,
          AppSpacing.space32,
        ),
        children: [
          AppFormSection(
            title: '基本信息',
            children: [
              AppPlainTextFormRow(
                label: '保险名称',
                controller: _nameController,
                hintText: '例如：百万医疗险',
                requiredIndicator: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入保险名称';
                  }
                  return null;
                },
              ),
              AppPlainTextFormRow(
                label: '保险公司',
                controller: _insurerController,
                hintText: '例如：平安保险',
                requiredIndicator: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入保险公司';
                  }
                  return null;
                },
              ),
              AppPlainChoiceChipFormRow<CommercialInsuranceCategory>(
                key: const ValueKey('commercial-category-choice'),
                label: '险种大类',
                value: state.category,
                requiredIndicator: true,
                layout: AppChoiceChipLayout.wrap,
                options: [
                  for (final category in CommercialInsuranceCategory.values)
                    AppChoiceChipOption(value: category, label: category.label),
                ],
                onChanged: notifier.setCategory,
              ),
              AppPlainTextFormRow(
                label: '产品形态',
                controller: _productFormController,
                hintText: '例如：定期寿险、增额终身寿',
                supportingText: '可选，用于补充产品名称之外的形态说明。',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          AppFormSection(
            title: '保障期间与保额',
            children: [
              AppPlainValueRow(
                label: '开始日期',
                value: insuranceDateLabel(state.coverageStartDate),
                onTap: () => _pickCoverageStartDate(notifier, state),
              ),
              AppPlainSwitchRow(
                label: '终身保障',
                description: '开启后不记录保障结束日期。',
                value: state.lifetime,
                onChanged: notifier.setLifetime,
              ),
              AppPlainValueRow(
                label: '结束日期',
                value: state.lifetime
                    ? '终身'
                    : state.coverageEndDate == null
                    ? '未设置'
                    : insuranceDateLabel(state.coverageEndDate!),
                enabled: !state.lifetime,
                onTap: state.lifetime
                    ? null
                    : () => _pickCoverageEndDate(notifier, state),
              ),
              MoneyPlainFormRow(
                label: '保额',
                controller: _coverageAmountController,
                hintText: '可选',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              AppPlainTextFormRow(
                label: '保额说明',
                controller: _coverageAmountNoteController,
                hintText: '例如：共享保额、按比例报销',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          AppFormSection(
            title: '缴费计划',
            description: '仅记录缴费摘要，不生成缴费期次或账务交易。',
            children: [
              AppPlainChoiceChipFormRow<PremiumFrequency>(
                key: const ValueKey('commercial-premium-frequency-choice'),
                label: '缴费频率',
                value: state.premiumFrequency,
                layout: AppChoiceChipLayout.wrap,
                options: [
                  for (final frequency in PremiumFrequency.values)
                    AppChoiceChipOption(
                      value: frequency,
                      label: frequency.label,
                    ),
                ],
                onChanged: notifier.setPremiumFrequency,
              ),
              MoneyPlainFormRow(
                label: '缴费金额',
                controller: _premiumAmountController,
                hintText: '可选',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              AppPlainTextFormRow(
                label: '缴费说明',
                controller: _premiumNoteController,
                hintText: '例如：首年优惠',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          AppFormSection(
            title: '被保险人',
            description: '一张商业保险可同时关联多个被保险人。',
            children: [
              for (
                var index = 0;
                index < state.insuredPeople.length;
                index++
              ) ...[
                AppPlainSwitchRow(
                  key: ValueKey(
                    'commercial-insured-person-'
                    '${state.insuredPeople[index].id}',
                  ),
                  label: state.insuredPeople[index].name,
                  description:
                      '出生：${insuranceDateLabel(state.insuredPeople[index].birthDate)}',
                  value: state.insuredPersonIds.contains(
                    state.insuredPeople[index].id,
                  ),
                  onChanged: (_) => notifier.toggleInsuredPerson(
                    state.insuredPeople[index].id,
                  ),
                ),
                if (index < state.insuredPeople.length - 1)
                  const AppListDivider(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          _ResponsibilityEditor(
            responsibilities: state.responsibilities,
            onAdd: () => _editResponsibility(notifier, null),
            onEdit: (responsibility) =>
                _editResponsibility(notifier, responsibility),
            onDelete: (responsibility) =>
                _deleteResponsibility(context, notifier, responsibility),
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: widget.insuranceId == null ? '保存商业保险' : '保存修改',
            loading: state.submitting,
            onPressed: () => _submit(context, notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverageStartDate(
    CommercialInsuranceFormViewModel notifier,
    CommercialInsuranceFormState state,
  ) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: state.coverageStartDate,
      firstYear: 1900,
      lastYear: 2200,
      title: '选择保障开始日期',
    );
    if (selected != null) notifier.setCoverageStartDate(selected);
  }

  Future<void> _pickCoverageEndDate(
    CommercialInsuranceFormViewModel notifier,
    CommercialInsuranceFormState state,
  ) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: state.coverageEndDate ?? state.coverageStartDate,
      firstYear: 1900,
      lastYear: 2200,
      title: '选择保障结束日期',
    );
    if (selected != null) notifier.setCoverageEndDate(selected);
  }

  Future<void> _editResponsibility(
    CommercialInsuranceFormViewModel notifier,
    InsuranceResponsibilityDraft? existing,
  ) async {
    final result = await showInsuranceResponsibilityEditor(
      context: context,
      existing: existing,
      newResponsibilityId: notifier.newResponsibilityDraftId,
      newPointId: notifier.newPointDraftId,
    );
    if (result != null) notifier.upsertResponsibility(result);
  }

  Future<void> _deleteResponsibility(
    BuildContext context,
    CommercialInsuranceFormViewModel notifier,
    InsuranceResponsibilityDraft responsibility,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除保障责任'),
        content: Text('确定删除“${responsibility.name}”及其全部责任要点吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.removeResponsibility(responsibility.id);
  }

  Future<void> _submit(
    BuildContext context,
    CommercialInsuranceFormViewModel notifier,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final outcome = await notifier.save(
      nameText: _nameController.text,
      insurerNameText: _insurerController.text,
      productFormText: _productFormController.text,
      coverageAmountText: _coverageAmountController.text,
      coverageAmountNoteText: _coverageAmountNoteController.text,
      premiumAmountText: _premiumAmountController.text,
      premiumNoteText: _premiumNoteController.text,
    );
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>():
        context.pop();
      case UiActionFailure<String>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _NoInsuredPeople extends StatelessWidget {
  const _NoInsuredPeople({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: '请先添加被保险人',
      message: '商业保险至少需要关联一位被保险人。',
      icon: const Icon(RemixIcons.user_heart_line),
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(RemixIcons.add_line),
        label: const Text('添加被保险人'),
      ),
    );
  }
}

class _ResponsibilityEditor extends StatelessWidget {
  const _ResponsibilityEditor({
    required this.responsibilities,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InsuranceResponsibilityDraft> responsibilities;
  final VoidCallback onAdd;
  final ValueChanged<InsuranceResponsibilityDraft> onEdit;
  final ValueChanged<InsuranceResponsibilityDraft> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFormSection(
          title: '保障责任',
          description: '责任要点用于记录摘要，完整合同依据保存在附件中。',
          trailing: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(RemixIcons.add_line, size: AppSpacing.space16),
            label: const Text('新增'),
          ),
          children: responsibilities.isEmpty
              ? [
                  const AppEmptyState(
                    title: '还没有保障责任项',
                    message: '可先保存基础信息，之后继续补充责任项。',
                    layout: AppEmptyStateLayout.inline,
                  ),
                ]
              : [
                  for (
                    var index = 0;
                    index < responsibilities.length;
                    index++
                  ) ...[
                    _ResponsibilityDraftRow(
                      draft: responsibilities[index],
                      onEdit: () => onEdit(responsibilities[index]),
                      onDelete: () => onDelete(responsibilities[index]),
                    ),
                    if (index < responsibilities.length - 1)
                      const AppListDivider(),
                  ],
                ],
        ),
      ],
    );
  }
}

class _ResponsibilityDraftRow extends StatelessWidget {
  const _ResponsibilityDraftRow({
    required this.draft,
    required this.onEdit,
    required this.onDelete,
  });

  final InsuranceResponsibilityDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('commercial-responsibility-${draft.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(AppSpacing.space8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.name, style: context.appTextStyles.listTitle),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      '${draft.kind.label} · ${draft.points.isEmpty ? '暂无责任要点' : '${draft.points.length} 条责任要点'}',
                      style: context.appTextStyles.listSupporting,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: '编辑保障责任',
            icon: const Icon(RemixIcons.edit_line),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: '删除保障责任',
            icon: const Icon(RemixIcons.delete_bin_line),
          ),
        ],
      ),
    );
  }
}
