import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/insurance/insurance_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_text_area_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/insured_person_form_view_model.dart';
import '../widget/member_avatar_picker_sheet.dart';
import '../widget/member_avatar_view.dart';

class InsuredPersonFormPage extends ConsumerWidget {
  const InsuredPersonFormPage({this.personId, super.key});

  final String? personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = insuredPersonFormViewModelProvider(personId);
    final asyncState = ref.watch(provider);
    final title = personId == null ? '新增成员' : '编辑成员';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(
              child: asyncState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (state) => state == null
                    ? const Center(child: Text('成员不存在'))
                    : _InsuredPersonFormContent(
                        key: ValueKey('insured-person-${personId ?? 'new'}'),
                        personId: personId,
                        initialState: state,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuredPersonFormContent extends ConsumerStatefulWidget {
  const _InsuredPersonFormContent({
    required this.personId,
    required this.initialState,
    super.key,
  });

  final String? personId;
  final InsuredPersonFormState initialState;

  @override
  ConsumerState<_InsuredPersonFormContent> createState() =>
      _InsuredPersonFormContentState();
}

class _InsuredPersonFormContentState
    extends ConsumerState<_InsuredPersonFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialState.name);
    _noteController = TextEditingController(
      text: widget.initialState.note ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.initialState;
    final notifier = ref.read(
      insuredPersonFormViewModelProvider(widget.personId).notifier,
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space16,
          AppSpacing.space16,
          AppSpacing.space32,
        ),
        children: [
          _AvatarEditor(
            preset: state.avatarPreset,
            onTap: () => _chooseAvatar(context, notifier, state),
          ),
          const SizedBox(height: AppSpacing.space20),
          AppFormSection(
            children: [
              AppPlainTextFormRow(
                label: '姓名',
                controller: _nameController,
                hintText: '请输入姓名',
                requiredIndicator: true,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入姓名' : null,
              ),
              AppPlainChoiceChipFormRow<MemberRelationship>(
                label: '关系',
                value: state.relationship,
                requiredIndicator: true,
                options: [
                  for (final relationship in MemberRelationship.values)
                    AppChoiceChipOption(
                      value: relationship,
                      label: relationship.label,
                    ),
                ],
                onChanged: notifier.setRelationship,
              ),
              AppPlainValueRow(
                label: '出生日期',
                value: state.birthDate == null
                    ? '请选择出生日期'
                    : insuranceDateLabel(state.birthDate!),
                valueColor: state.birthDate == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
                onTap: () => _pickBirthDate(context, state),
              ),
              AppPlainChoiceChipFormRow<MemberGender>(
                label: '性别',
                value: state.gender,
                layout: AppChoiceChipLayout.equalWidth,
                requiredIndicator: true,
                options: [
                  for (final gender in MemberGender.values)
                    AppChoiceChipOption(value: gender, label: gender.label),
                ],
                onChanged: notifier.setGender,
              ),
              AppPlainTextAreaFormRow(
                label: '备注',
                controller: _noteController,
                hintText: '可选，填写相关备注',
                maxLength: 100,
                minLines: 3,
                maxLines: 4,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space20),
          AppSubmitButton(
            label: '保存',
            loading: state.submitting,
            onPressed: () => _submit(context, notifier, state),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseAvatar(
    BuildContext context,
    InsuredPersonFormViewModel notifier,
    InsuredPersonFormState state,
  ) async {
    final selected = await showMemberAvatarPickerSheet(
      context,
      selected: state.avatarPreset,
    );
    if (selected != null) notifier.setAvatarPreset(selected);
  }

  Future<void> _pickBirthDate(
    BuildContext context,
    InsuredPersonFormState state,
  ) async {
    final now = DateTime.now();
    final initialDate = state.birthDate == null
        ? DateTime(now.year - 30, now.month, now.day)
        : state.birthDate!;
    final provider = insuredPersonFormViewModelProvider(widget.personId);
    final notifier = ref.read(provider.notifier);
    final selected = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstYear: 1900,
      lastYear: now.year,
      title: '选择出生日期',
    );
    if (selected != null) notifier.setBirthDate(selected);
  }

  Future<void> _submit(
    BuildContext context,
    InsuredPersonFormViewModel notifier,
    InsuredPersonFormState state,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final outcome = await notifier.save(
      nameText: _nameController.text,
      birthDate: state.birthDate,
      noteText: _noteController.text,
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

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({required this.preset, required this.onTap});

  final MemberAvatarPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: '选择头像',
        child: InkWell(
          key: const ValueKey('member-avatar-editor'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.space48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space20,
              vertical: AppSpacing.space8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatarView(preset: preset, size: 88),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  '选择头像',
                  style: context.appTextStyles.formValue.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
