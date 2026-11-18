import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_region_picker.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/presentation/china_region_data.dart';
import '../view_model/social_insurance_form_view_model.dart';
import '../widget/insured_person_picker_sheet.dart';

class SocialInsuranceFormPage extends ConsumerWidget {
  const SocialInsuranceFormPage({
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

  final String? insuranceId;
  final String? initialInsuredPersonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = socialInsuranceFormViewModelProvider(
      insuranceId,
      initialInsuredPersonId,
    );
    final state = ref.watch(provider);
    final title = insuranceId == null ? '新增社保' : '编辑社保';
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
                    key: ValueKey('social-insurance-${insuranceId ?? 'new'}'),
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
    required this.initialState,
    this.insuranceId,
    this.initialInsuredPersonId,
    super.key,
  });

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
  AppRegionSelection? _selectedRegion;

  @override
  Widget build(BuildContext context) {
    final state = widget.initialState;
    final provider = socialInsuranceFormViewModelProvider(
      widget.insuranceId,
      widget.initialInsuredPersonId,
    );
    final notifier = ref.read(provider.notifier);
    final locked = state.typesLocked;
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
            description: locked ? '社保类型或参保类型发生变化时，请新建社保记录以保留历史。' : null,
            children: [
              AppPlainSelectFormRow<String>(
                key: const ValueKey('social-insured-person-select'),
                label: '参保人',
                requiredIndicator: true,
                value: state.insuredPersonId,
                valueText: state.insuredPerson?.name,
                placeholder: '请选择',
                validator: (value) => value == null ? '请选择参保人' : null,
                onChanged: (value) {
                  if (value != null) notifier.setInsuredPersonId(value);
                },
                onTap: (onSelected) async {
                  final selected = await showInsuredPersonPickerSheet(
                    context: context,
                    people: state.insuredPeople,
                    selectedId: state.insuredPersonId,
                  );
                  if (mounted && selected != null) onSelected(selected);
                },
              ),
              AppPlainSelectFormRow<String>(
                key: const ValueKey('social-region-select'),
                label: '参保地区',
                value: state.region.isEmpty ? null : state.region,
                placeholder: '请选择省、市',
                requiredIndicator: true,
                validator: (value) =>
                    value == null || value.isEmpty ? '请选择参保地区' : null,
                onChanged: (value) {
                  if (value != null) notifier.setRegion(value);
                },
                onTap: (onSelected) => _pickRegion(onSelected),
              ),
              AppPlainChoiceChipFormRow<SocialInsuranceType>(
                key: const ValueKey('social-type-choice'),
                label: '社保类型',
                value: state.insuranceType,
                requiredIndicator: true,
                enabled: !locked,
                options: [
                  for (final type in SocialInsuranceType.values)
                    AppChoiceChipOption(value: type, label: type.label),
                ],
                onChanged: notifier.setInsuranceType,
              ),
              AppPlainChoiceChipFormRow<SocialParticipantType>(
                key: const ValueKey('social-participant-type-choice'),
                label: '参保类型',
                value: state.participantType,
                requiredIndicator: true,
                enabled: !locked,
                reservedRows: 1,
                options: [
                  for (final type in SocialParticipantType.values)
                    AppChoiceChipOption(value: type, label: type.label),
                ],
                onChanged: notifier.setParticipantType,
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
    final outcome = await notifier.save();
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

  Future<void> _pickRegion(ValueChanged<String?> onSelected) async {
    final outcome = await guardUiAction<List<AppRegionNode>>(
      Logger('feature.insurance.social_form'),
      'Load region data',
      loadChinaRegions,
    );
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<List<AppRegionNode>>(:final value):
        final selected = await showAppRegionPickerSheet(
          context: context,
          regions: value,
          level: AppRegionLevel.city,
          selectedCodes:
              _selectedRegion?.codes ??
              findChinaRegionCitySelection(
                regions: value,
                label: widget.initialState.region,
              )?.codes ??
              const [],
          title: '选择参保地区',
        );
        if (!mounted || selected == null) return;
        _selectedRegion = selected;
        onSelected(selected.label);
      case UiActionFailure<List<AppRegionNode>>(:final error):
        _showError(context, error.message);
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
