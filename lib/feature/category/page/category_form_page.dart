import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/category_form_view_model.dart';

class CategoryFormPage extends ConsumerWidget {
  const CategoryFormPage({
    super.key,
    this.initialType = AccountType.expense,
    this.initialParentId,
    this.categoryId,
  });

  final AccountType initialType;
  final String? initialParentId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(
      categoryFormViewModelProvider(
        categoryId: categoryId,
        initialType: initialType,
        initialParentId: initialParentId,
      ),
    );
    return switch (asyncState) {
      AsyncData(value: final formState) when formState != null =>
        _CategoryFormContent(
          key: ValueKey<String?>(categoryId),
          categoryId: categoryId,
          initialType: initialType,
          initialParentId: initialParentId,
          formState: formState,
        ),
      AsyncData(value: null) => const _CategoryFormStatusPage(
        title: '编辑分类',
        message: '分类不存在',
      ),
      AsyncError() => _CategoryFormStatusPage(
        title: categoryId == null ? '新增分类' : '编辑分类',
        message: '分类加载失败，请稍后重试',
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _CategoryFormStatusPage extends StatelessWidget {
  const _CategoryFormStatusPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(message)),
    );
  }
}

class _CategoryFormContent extends ConsumerStatefulWidget {
  const _CategoryFormContent({
    required this.categoryId,
    required this.initialType,
    required this.initialParentId,
    required this.formState,
    super.key,
  });

  final String? categoryId;
  final AccountType initialType;
  final String? initialParentId;
  final CategoryFormState formState;

  @override
  ConsumerState<_CategoryFormContent> createState() =>
      _CategoryFormContentState();
}

class _CategoryFormContentState extends ConsumerState<_CategoryFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;

  bool get _isEditMode => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    final initialValues = widget.formState.initialValues;
    _nameController = TextEditingController(text: initialValues.name);
    _noteController = TextEditingController(text: initialValues.note);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFormScaffold(context, widget.formState);
  }

  Widget _buildFormScaffold(BuildContext context, CategoryFormState formState) {
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(_formProvider.notifier);
    final parentTree =
        formState.type == AccountType.income
            ? formState.incomeTree
            : formState.expenseTree;
    final parentOptions = categoryParentOptions(
      nodes: parentTree,
      type: formState.type,
      editingCategoryId: widget.categoryId,
    );
    final effectiveParent =
        parentOptions
            .where((parent) => parent.id == formState.parentId)
            .firstOrNull;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _CategoryFormHeader(
                title: _isEditMode ? '编辑分类' : '新增分类',
                submitting: formState.submitting,
                onSave: _submit,
              ),
              if (!_isEditMode) ...[
                _TypeTabs(type: formState.type, onChanged: notifier.setType),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space20,
                    AppSpacing.space16,
                    AppSpacing.space20,
                    AppSpacing.space24,
                  ),
                  children: [
                    AppFormSection(
                      title: '分类图标',
                      description: '图标会用于记账和统计展示',
                      children: [
                        IconCatalogPicker(
                          usage: _iconUsageForType(formState.type),
                          selectedKey: formState.iconKey,
                          onChanged: notifier.setIconKey,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '基本信息',
                      children: [
                        AppPlainTextFormRow(
                          label: '分类名称',
                          requiredIndicator: true,
                          controller: _nameController,
                          hintText: '请输入分类名称',
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? '请输入分类名称'
                                      : null,
                        ),
                        AppPlainSelectFormRow<String>(
                          label: '父分类',
                          value: formState.parentId,
                          valueText: effectiveParent?.name ?? '无',
                          placeholder: '无',
                          onTap:
                              (onSelected) =>
                                  _showParentSheet(parentOptions, onSelected),
                          onChanged: notifier.setParentId,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '其他',
                      children: [
                        AppPlainTextFormRow(
                          label: '备注',
                          controller: _noteController,
                          hintText: '请输入备注（可选）',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CategoryFormViewModelProvider get _formProvider =>
      categoryFormViewModelProvider(
        categoryId: widget.categoryId,
        initialType: widget.initialType,
        initialParentId: widget.initialParentId,
      );

  Future<void> _showParentSheet(
    List<Account> parents,
    ValueChanged<String?> onSelected,
  ) async {
    final parentId = ref.read(_formProvider).requireValue!.parentId;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(
                  parentId == null
                      ? RemixIcons.checkbox_circle_fill
                      : RemixIcons.checkbox_blank_circle_line,
                ),
                title: const Text('无'),
                onTap: () => Navigator.of(context).pop(''),
              ),
              for (final parent in parents)
                ListTile(
                  leading: Icon(
                    parentId == parent.id
                        ? RemixIcons.checkbox_circle_fill
                        : RemixIcons.checkbox_blank_circle_line,
                  ),
                  title: Text(parent.name),
                  onTap: () => Navigator.of(context).pop(parent.id),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    onSelected(selected.isEmpty ? null : selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final outcome = await ref
        .read(_formProvider.notifier)
        .submit(nameText: _nameController.text, noteText: _noteController.text);
    if (!mounted) return;

    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _CategoryFormHeader extends StatelessWidget {
  const _CategoryFormHeader({
    required this.title,
    required this.submitting,
    required this.onSave,
  });

  final String title;
  final bool submitting;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space12,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(RemixIcons.arrow_left_s_line),
              iconSize: 32,
              tooltip: '返回',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: submitting ? null : onSave,
              child:
                  submitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('保存'),
            ),
          ),
          Text(title, style: context.appTextStyles.sectionTitleStrong),
        ],
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.type, required this.onChanged});

  final AccountType type;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeTab(
          label: '支出',
          selected: type == AccountType.expense,
          onTap: () => onChanged(AccountType.expense),
        ),
        _TypeTab(
          label: '收入',
          selected: type == AccountType.income,
          onTap: () => onChanged(AccountType.income),
        ),
      ],
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space14),
              child: Text(
                label,
                style: textStyles
                    .segmentedControlLabel(selected: selected)
                    .copyWith(
                      color:
                          selected ? colors.primary : colors.onSurfaceVariant,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 82 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BusinessIconUsage _iconUsageForType(AccountType type) {
  return type == AccountType.income
      ? BusinessIconUsage.incomeCategory
      : BusinessIconUsage.expenseCategory;
}
