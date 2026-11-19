import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_form_view_model.dart';
import '../../../design_system/widget/app_scaffold.dart';

class CommercialInsuranceFormPage extends ConsumerStatefulWidget {
  const CommercialInsuranceFormPage({
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final String? insuranceId;
  final String? initialInsuredPersonId;

  @override
  ConsumerState<CommercialInsuranceFormPage> createState() =>
      _CommercialInsuranceFormPageState();
}

class _CommercialInsuranceFormPageState
    extends ConsumerState<CommercialInsuranceFormPage> {
  var _contentKey = GlobalKey<_CommercialInsuranceFormContentState>();

  @override
  void didUpdateWidget(covariant CommercialInsuranceFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insuranceId != widget.insuranceId ||
        oldWidget.initialInsuredPersonId != widget.initialInsuredPersonId) {
      _contentKey = GlobalKey<_CommercialInsuranceFormContentState>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final insuranceId = widget.insuranceId;
    final initialInsuredPersonId = widget.initialInsuredPersonId;
    final provider = commercialInsuranceFormViewModelProvider(
      insuranceId,
      initialInsuredPersonId,
    );
    final state = ref.watch(provider);
    final loaded = state.asData?.value;
    final title = insuranceId == null ? '新增商业保险' : '编辑商业保险';
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: title,
              actions: [
                AppHeaderTextButton(
                  key: const ValueKey('commercial-form-save'),
                  label: '保存',
                  onPressed:
                      loaded == null ||
                          loaded.insuredPeople.isEmpty ||
                          loaded.submitting
                      ? null
                      : () => _contentKey.currentState?._submit(
                          context,
                          ref.read(provider.notifier),
                        ),
                ),
              ],
            ),
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
                    key: _contentKey,
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
  late final TextEditingController _policyholderController;
  late final TextEditingController _beneficiaryController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialState.initialValues;
    _nameController = TextEditingController(text: initial.name);
    _insurerController = TextEditingController(text: initial.insurerName);
    _productFormController = TextEditingController(text: initial.productForm);
    _policyholderController = TextEditingController(
      text: initial.policyholderName,
    );
    _beneficiaryController = TextEditingController(
      text: initial.beneficiaryDescription,
    );
    _coverageAmountController = TextEditingController(
      text: initial.coverageAmount,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _insurerController.dispose();
    _productFormController.dispose();
    _coverageAmountController.dispose();
    _policyholderController.dispose();
    _beneficiaryController.dispose();
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
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          AppFormSection(
            key: const ValueKey('commercial-contract-information'),
            title: '合同信息',
            children: [
              AppPlainValueRow(
                label: '开始日期',
                value: insuranceDateLabel(state.coverageStartDate),
                onTap: () => _pickCoverageStartDate(notifier, state),
              ),
              AppPlainSwitchRow(
                label: '终身保障',
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
                key: const ValueKey('commercial-policyholder'),
                label: '投保人',
                controller: _policyholderController,
                hintText: '可选，填写个人或单位名称',
              ),
              AppPlainTextAreaFormRow(
                key: const ValueKey('commercial-beneficiary'),
                label: '受益人',
                controller: _beneficiaryController,
                hintText: '可选，填写姓名或合同约定',
                layout: AppPlainFormRowLayout.vertical,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          AppFormSection(
            title: '被保险人',
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
                  label:
                      '${state.insuredPeople[index].name} · '
                      '${state.insuredPeople[index].relationship.label} · '
                      '${state.insuredPeople[index].ageAt(DateTime.now())} 岁',
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
      policyholderNameText: _policyholderController.text,
      beneficiaryDescriptionText: _beneficiaryController.text,
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
