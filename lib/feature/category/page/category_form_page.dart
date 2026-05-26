import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../application/ledger/ledger_api.dart';
import '../../../widget/business/business_icon.dart';
import '../../../widget/business/icon_choice_grid.dart';

class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({
    super.key,
    this.initialType = AccountType.expense,
    this.initialParentId,
  });

  final AccountType initialType;
  final int? initialParentId;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  AccountType _type = AccountType.expense;
  int? _parentId;
  String? _iconKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _parentId = widget.initialParentId;
    _iconKey = _defaultIconKeyForType(_type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parentOptions = ref
        .watch(categoryTreeProvider(_type))
        .maybeWhen(
          data: (nodes) => nodes.map((node) => node.account).toList(),
          orElse: () => const <Account>[],
        );
    final effectiveParent =
        parentOptions.where((parent) => parent.id == _parentId).firstOrNull;
    if (effectiveParent == null && _parentId != null) {
      _parentId = null;
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _CategoryFormHeader(submitting: _submitting, onSave: _submit),
              _TypeTabs(type: _type, onChanged: _switchType),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space28,
                    AppSpacing.space24,
                    AppSpacing.space28,
                    AppSpacing.space24,
                  ),
                  children: [
                    IconChoiceGrid(
                      choices: _categoryIconGridItemsForType(_type),
                      selectedKey: _iconKey,
                      onChanged: (value) => setState(() => _iconKey = value),
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    const Divider(height: 1),
                    AppPlainFormRow(
                      label: '分类名称',
                      child: AppPlainTextFormField(
                        controller: _nameController,
                        hintText: '请输入分类名称',
                        validator:
                            (value) =>
                                value == null || value.trim().isEmpty
                                    ? '请输入分类名称'
                                    : null,
                      ),
                    ),
                    const Divider(height: 1),
                    AppPlainFormRow(
                      label: '父分类',
                      onTap: () => _showParentSheet(parentOptions),
                      child: AppPlainValueText(
                        text: effectiveParent?.name ?? '无',
                      ),
                    ),
                    const Divider(height: 1),
                    AppPlainFormRow(
                      label: '备注',
                      child: AppPlainTextFormField(
                        controller: _noteController,
                        hintText: '请输入备注（可选）',
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchType(AccountType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _parentId = null;
      _iconKey = _defaultIconKeyForType(type);
    });
  }

  Future<void> _showParentSheet(List<Account> parents) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(
                  _parentId == null
                      ? RemixIcons.checkbox_circle_fill
                      : RemixIcons.checkbox_blank_circle_line,
                ),
                title: const Text('无'),
                onTap: () => Navigator.of(context).pop(-1),
              ),
              for (final parent in parents)
                ListTile(
                  leading: Icon(
                    _parentId == parent.id
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
    setState(() => _parentId = selected == -1 ? null : selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final result = await ref
        .read(categoryServiceProvider)
        .createCategory(
          CreateCategoryCommand(
            name: _nameController.text,
            type: _type,
            parentId: _parentId,
            iconKey: _iconKey,
            note: _noteController.text,
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        context.pop();
      case FailureResult(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _CategoryFormHeader extends StatelessWidget {
  const _CategoryFormHeader({required this.submitting, required this.onSave});

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
          Text('新增分类', style: context.appTextStyles.sectionTitleStrong),
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

String _defaultIconKeyForType(AccountType type) {
  return businessIconSpecsForUsage(_iconUsageForType(type)).first.iconKey;
}

List<IconChoiceGridItem> _categoryIconGridItemsForType(AccountType type) {
  return [
    for (final spec in businessIconSpecsForUsage(_iconUsageForType(type)))
      IconChoiceGridItem(
        iconKey: spec.iconKey,
        label: spec.label,
        iconBuilder:
            (context, size) => BusinessIcon(iconKey: spec.iconKey, size: size),
      ),
  ];
}
