import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_dropdown.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/social_insurance_form_view_model.dart';

class SocialInsuranceFormPage extends ConsumerWidget {
  const SocialInsuranceFormPage({
    required this.sourceType,
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final InsuranceSourceType sourceType;
  final String? insuranceId;
  final String? initialInsuredPersonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = socialInsuranceFormViewModelProvider(
      insuranceId,
      sourceType,
      initialInsuredPersonId,
    );
    final state = ref.watch(provider);
    final title = insuranceId == null
        ? '新增${sourceType.label}'
        : '编辑${sourceType.label}';
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
                    return const Center(child: Text('社保记录不存在'));
                  }
                  if (value.insuredPeople.isEmpty) {
                    return _NoInsuredPeople(
                      onAdd: () => _addInsuredPerson(context, ref, provider),
                    );
                  }
                  return _SocialInsuranceFormContent(
                    key: ValueKey('${sourceType.name}:${insuranceId ?? 'new'}'),
                    sourceType: sourceType,
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
    SocialInsuranceFormViewModelProvider provider,
  ) async {
    await context.push('/insurance/members/new');
    if (context.mounted) ref.invalidate(provider);
  }
}

class _SocialInsuranceFormContent extends ConsumerStatefulWidget {
  const _SocialInsuranceFormContent({
    required this.sourceType,
    required this.initialState,
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final InsuranceSourceType sourceType;
  final String? insuranceId;
  final String? initialInsuredPersonId;
  final SocialInsuranceFormState initialState;

  @override
  ConsumerState<_SocialInsuranceFormContent> createState() =>
      _SocialInsuranceFormContentState();
}

class _SocialInsuranceFormContentState
    extends ConsumerState<_SocialInsuranceFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _regionController;

  @override
  void initState() {
    super.initState();
    _regionController = TextEditingController(text: widget.initialState.region);
  }

  @override
  void dispose() {
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.initialState;
    final provider = socialInsuranceFormViewModelProvider(
      widget.insuranceId,
      widget.sourceType,
      widget.initialInsuredPersonId,
    );
    final notifier = ref.read(provider.notifier);
    final locked = state.identityLocked;
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
            title: '参保信息',
            description: locked ? '参保地区或参保类型发生变化时，请新建一条社保记录以保留历史。' : null,
            children: [
              AppPlainFormRow(
                label: '参保人',
                requiredIndicator: true,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppDropdown<String?>(
                    value: state.insuredPersonId,
                    tooltip: '选择参保人',
                    options: [
                      const AppSelectOption(value: null, label: '请选择'),
                      for (final person in state.insuredPeople)
                        AppSelectOption(value: person.id, label: person.name),
                    ],
                    onChanged: (value) {
                      if (value != null) notifier.setInsuredPersonId(value);
                    },
                  ),
                ),
              ),
              AppPlainTextFormRow(
                label: '参保地区',
                controller: _regionController,
                hintText: '例如：上海市',
                requiredIndicator: true,
                readOnly: locked,
                supportingText: locked ? '编辑时不可修改，请新建记录。' : null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入参保地区';
                  }
                  return null;
                },
              ),
              if (locked)
                AppPlainValueRow(
                  label: '参保类型',
                  value: state.participantType.label,
                )
              else
                AppPlainFormRow(
                  label: '参保类型',
                  requiredIndicator: true,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppDropdown<SocialParticipantType>(
                      value: state.participantType,
                      tooltip: '选择参保类型',
                      options: [
                        for (final type in SocialParticipantType.values)
                          AppSelectOption(value: type, label: type.label),
                      ],
                      onChanged: notifier.setParticipantType,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: widget.insuranceId == null ? '保存记录' : '保存修改',
            loading: state.submitting,
            onPressed: () => _submit(context, notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    SocialInsuranceFormViewModel notifier,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final outcome = await notifier.save(regionText: _regionController.text);
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>():
        context.pop();
      case UiActionFailure<String>(:final error):
        _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoInsuredPeople extends StatelessWidget {
  const _NoInsuredPeople({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: '请先添加被保险人',
      message: '社保记录必须关联一位被保险人。',
      icon: const Icon(RemixIcons.user_heart_line),
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(RemixIcons.add_line),
        label: const Text('添加被保险人'),
      ),
    );
  }
}
