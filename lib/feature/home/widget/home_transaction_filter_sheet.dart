import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/account/account_multi_select_sheet.dart';
import '../../../widget/business/category/category_cascade_multi_select_sheet.dart';
import '../../../widget/business/tag/tag_multi_select_sheet.dart';
import '../view_model/home_view_model.dart';

Future<HomeTransactionFilter?> showHomeTransactionFilterSheet({
  required BuildContext context,
  required HomeTransactionFilter initialFilter,
  required List<CategoryNode> expenseTree,
  required List<CategoryNode> incomeTree,
  required List<Account> accounts,
}) {
  return showModalBottomSheet<HomeTransactionFilter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => _HomeTransactionFilterSheet(
          initialFilter: initialFilter,
          expenseTree: expenseTree,
          incomeTree: incomeTree,
          accounts: accounts,
        ),
  );
}

class _HomeTransactionFilterSheet extends ConsumerStatefulWidget {
  const _HomeTransactionFilterSheet({
    required this.initialFilter,
    required this.expenseTree,
    required this.incomeTree,
    required this.accounts,
  });

  final HomeTransactionFilter initialFilter;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;
  final List<Account> accounts;

  @override
  ConsumerState<_HomeTransactionFilterSheet> createState() =>
      _HomeTransactionFilterSheetState();
}

class _HomeTransactionFilterSheetState
    extends ConsumerState<_HomeTransactionFilterSheet> {
  late final Set<String> _allCategoryIds = _categoryTreeIds(
    widget.expenseTree,
    widget.incomeTree,
  );
  late final Set<String> _allAccountIds = {
    for (final account in widget.accounts) account.id,
  };
  late Set<String> _selectedCategoryIds =
      widget.initialFilter.categoryAccountIds == null
          ? Set.of(_allCategoryIds)
          : widget.initialFilter.categoryAccountIds!.intersection(
            _allCategoryIds,
          );
  late Set<String> _selectedAccountIds =
      widget.initialFilter.settlementAccountIds == null
          ? Set.of(_allAccountIds)
          : widget.initialFilter.settlementAccountIds!.intersection(
            _allAccountIds,
          );
  late Set<String> _selectedTagIds = Set.of(
    widget.initialFilter.tagIds ?? const <String>{},
  );
  late bool _untaggedOnly = widget.initialFilter.untaggedOnly;

  bool get _allSelected =>
      _selectedCategoryIds.length == _allCategoryIds.length &&
      _selectedAccountIds.length == _allAccountIds.length &&
      _selectedTagIds.isEmpty &&
      !_untaggedOnly;

  bool get _noneSelected =>
      _selectedCategoryIds.isEmpty &&
      _selectedAccountIds.isEmpty &&
      _selectedTagIds.isEmpty &&
      !_untaggedOnly;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '交易筛选',
                    style: context.appTextStyles.subsectionTitle,
                  ),
                ),
                TextButton(
                  onPressed:
                      _allSelected
                          ? null
                          : () => setState(() {
                            _selectedCategoryIds = Set.of(_allCategoryIds);
                            _selectedAccountIds = Set.of(_allAccountIds);
                            _selectedTagIds = {};
                            _untaggedOnly = false;
                          }),
                  child: const Text('全部'),
                ),
                TextButton(
                  onPressed:
                      _noneSelected
                          ? null
                          : () => setState(() {
                            _selectedCategoryIds = {};
                            _selectedAccountIds = {};
                            _selectedTagIds = {};
                            _untaggedOnly = false;
                          }),
                  child: const Text('清除'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            AppPlainFormSection(
              children: [
                AppPlainValueRow(
                  label: '分类',
                  value: _selectionLabel(_selectedCategoryIds, _allCategoryIds),
                  onTap: _selectCategories,
                ),
                AppPlainValueRow(
                  label: '账户',
                  value: _selectionLabel(_selectedAccountIds, _allAccountIds),
                  onTap: _selectAccounts,
                ),
                AppPlainValueRow(
                  label: '标签',
                  value: _tagLabel,
                  onTap: _selectTags,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            AppSubmitButton(label: '应用', onPressed: _apply),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategories() async {
    final selected = await showCategoryCascadeMultiSelectSheet(
      context: context,
      expenseTree: widget.expenseTree,
      incomeTree: widget.incomeTree,
      selectedIds: _selectedCategoryIds,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedCategoryIds = selected);
  }

  Future<void> _selectAccounts() async {
    final selected = await showAccountMultiSelectSheet(
      context: context,
      accounts: widget.accounts,
      selectedIds: _selectedAccountIds,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedAccountIds = selected);
  }

  Future<void> _selectTags() async {
    final tags = await ref.read(tagApplicationServiceProvider).listTags();
    if (!mounted) return;
    final result = await showTagMultiSelectSheet(
      context: context,
      tags: tags,
      selectedIds: _selectedTagIds,
      untaggedOnly: _untaggedOnly,
      allowUntagged: true,
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedTagIds = result.selectedTagIds;
      _untaggedOnly = result.untaggedOnly;
    });
  }

  String get _tagLabel {
    if (_untaggedOnly) return '未打标签';
    if (_selectedTagIds.isEmpty) return '不限';
    return '已选 ${_selectedTagIds.length} 项';
  }

  void _apply() {
    Navigator.of(context).pop(
      HomeTransactionFilter(
        categoryAccountIds: _normalize(_selectedCategoryIds, _allCategoryIds),
        settlementAccountIds: _normalize(_selectedAccountIds, _allAccountIds),
        tagIds:
            _untaggedOnly || _selectedTagIds.isEmpty ? null : _selectedTagIds,
        untaggedOnly: _untaggedOnly,
      ),
    );
  }

  Set<String>? _normalize(Set<String> selected, Set<String> all) {
    if (selected.isEmpty ||
        (selected.length == all.length && selected.containsAll(all))) {
      return null;
    }
    return selected;
  }

  String _selectionLabel(Set<String> selected, Set<String> all) {
    if (selected.length == all.length && selected.containsAll(all)) return '全部';
    if (selected.isEmpty) return '未选择';
    return '已选 ${selected.length} 项';
  }
}

Set<String> _categoryTreeIds(
  List<CategoryNode> expenseTree,
  List<CategoryNode> incomeTree,
) {
  return {
    for (final node in [...expenseTree, ...incomeTree]) ...[
      node.account.id,
      for (final child in node.children) child.id,
    ],
  };
}
