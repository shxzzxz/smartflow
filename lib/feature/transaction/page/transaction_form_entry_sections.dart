part of 'transaction_form_page.dart';

class _CategoryEntryArea extends StatelessWidget {
  const _CategoryEntryArea({
    required this.state,
    required this.categoryType,
    required this.categoryTree,
    required this.categoryLabel,
    required this.emptyLabel,
    required this.settlementTitle,
    required this.settlementAddLabel,
    required this.onSelectCategory,
    required this.onAddRootCategory,
    required this.onAddChildCategory,
    required this.onCategoryAllocationsChanged,
    required this.onSettlementAllocationsChanged,
  });

  final TransactionFormState state;
  final AccountType categoryType;
  final List<CategoryNode> categoryTree;
  final String categoryLabel;
  final String emptyLabel;
  final String settlementTitle;
  final String settlementAddLabel;
  final void Function(String? rootId, String? categoryId) onSelectCategory;
  final VoidCallback onAddRootCategory;
  final ValueChanged<String> onAddChildCategory;
  final ValueChanged<List<AccountAmountAllocation>>
  onCategoryAllocationsChanged;
  final ValueChanged<List<AccountAmountAllocation>>
  onSettlementAllocationsChanged;

  @override
  Widget build(BuildContext context) {
    final settlementAccounts = state.isAmortization
        ? state.settlementAccounts
        : categoryType == AccountType.expense
        ? state.expenseSettlementAccounts
        : state.settlementAccounts;
    if (state.entryMode == TransactionEntryMode.allocated) {
      final total = sumAllocations(state.categoryAllocations);
      return Column(
        key: ValueKey('${categoryType.name}-entry-allocated'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransactionInlineAllocationColumn(
            key: ValueKey('${categoryType.name}-category-allocations'),
            title: '多分类',
            allocations: state.categoryAllocations,
            options: _categoryOptions(
              categoryTree,
              iconUsage: categoryType == AccountType.income
                  ? BusinessIconUsage.incomeCategory
                  : BusinessIconUsage.expenseCategory,
            ),
            addLabel: '添加分类',
            statusInHeader: true,
            onSelectOption: (context, selectedId, options) =>
                _showCategoryAllocationPickerSheet(
                  context: context,
                  nodes: categoryTree,
                  options: options,
                  selectedId: selectedId,
                  onAddRootCategory: onAddRootCategory,
                  onAddChildCategory: onAddChildCategory,
                ),
            onChanged: onCategoryAllocationsChanged,
          ),
          const SizedBox(height: AppSpacing.space8),
          TransactionInlineAllocationColumn(
            key: ValueKey('${categoryType.name}-settlement-allocations'),
            title: settlementTitle,
            allocations: state.settlementAllocations,
            options: transactionAllocationOptionsForAccounts(
              settlementAccounts,
            ),
            addLabel: settlementAddLabel,
            expectedTotal: total,
            statusInHeader: true,
            onSelectOption: (context, selectedId, options) async {
              final optionIds = {
                for (final option in options) option.accountId,
              };
              final selected = await showAccountPickerSheet(
                context: context,
                accounts: [
                  for (final account in settlementAccounts)
                    if (optionIds.contains(account.id)) account,
                ],
                selectedId: selectedId,
              );
              if (selected == null) return null;
              return options
                  .where((option) => option.accountId == selected)
                  .firstOrNull;
            },
            onChanged: onSettlementAllocationsChanged,
          ),
        ],
      );
    }

    return AppControlledFormField<String>(
      key: ValueKey('${categoryType.name}-entry-normal'),
      value: state.mode == TransactionFormMode.expense
          ? state.expenseCategoryId
          : state.incomeCategoryId,
      validator: (value) => value == null ? '请选择$categoryLabel' : null,
      builder: (context, _, errorText, onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryGridPicker(
            nodes: categoryTree,
            selectedRootId: state.mode == TransactionFormMode.expense
                ? state.expenseRootId
                : state.incomeRootId,
            selectedCategoryId: state.mode == TransactionFormMode.expense
                ? state.expenseCategoryId
                : state.incomeCategoryId,
            emptyLabel: emptyLabel,
            onRootSelected: (account) {
              onSelectCategory(account.id, account.id);
              onChanged(account.id);
            },
            onChildSelected: (root, child) {
              onSelectCategory(root.id, child.id);
              onChanged(child.id);
            },
            onAddRoot: onAddRootCategory,
            onAddChild: onAddChildCategory,
          ),
          if (errorText != null) _FormFieldErrorText(errorText),
        ],
      ),
    );
  }
}

Future<TransactionAllocationOption?> _showCategoryAllocationPickerSheet({
  required BuildContext context,
  required List<CategoryNode> nodes,
  required List<TransactionAllocationOption> options,
  required String? selectedId,
  required VoidCallback onAddRootCategory,
  required ValueChanged<String> onAddChildCategory,
}) {
  return showModalBottomSheet<TransactionAllocationOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CategoryAllocationPickerSheet(
      nodes: nodes,
      options: options,
      selectedId: selectedId,
      onAddRootCategory: onAddRootCategory,
      onAddChildCategory: onAddChildCategory,
    ),
  );
}

class _CategoryAllocationPickerSheet extends StatefulWidget {
  const _CategoryAllocationPickerSheet({
    required this.nodes,
    required this.options,
    required this.selectedId,
    required this.onAddRootCategory,
    required this.onAddChildCategory,
  });

  final List<CategoryNode> nodes;
  final List<TransactionAllocationOption> options;
  final String? selectedId;
  final VoidCallback onAddRootCategory;
  final ValueChanged<String> onAddChildCategory;

  @override
  State<_CategoryAllocationPickerSheet> createState() =>
      _CategoryAllocationPickerSheetState();
}

class _CategoryAllocationPickerSheetState
    extends State<_CategoryAllocationPickerSheet> {
  String? _selectedRootId;
  String? _selectedCategoryId;

  Set<String> get _selectableIds => {
    for (final option in widget.options) option.accountId,
  };

  TransactionAllocationOption? get _selectedOption {
    final selectedId = _selectedCategoryId;
    if (selectedId == null) return null;
    return widget.options
        .where((option) => option.accountId == selectedId)
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    final selectedId = widget.selectedId;
    if (selectedId == null || !_selectableIds.contains(selectedId)) return;
    _selectedCategoryId = selectedId;
    for (final node in widget.nodes) {
      if (node.account.id == selectedId ||
          node.children.any((child) => child.id == selectedId)) {
        _selectedRootId = node.account.id;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        AppComponentTokens.selectionSheetMaxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Text('选择分类', style: context.appTextStyles.subsectionTitle),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
                child: CategoryGridPicker(
                  nodes: widget.nodes,
                  selectedRootId: _selectedRootId,
                  selectedCategoryId: _selectedCategoryId,
                  emptyLabel: '尚未创建支出分类',
                  onRootSelected: (account) => setState(() {
                    _selectedRootId = account.id;
                    _selectedCategoryId = _selectableIds.contains(account.id)
                        ? account.id
                        : null;
                  }),
                  onChildSelected: (root, child) => setState(() {
                    _selectedRootId = root.id;
                    _selectedCategoryId = child.id;
                  }),
                  onAddRoot: () {
                    Navigator.of(context).pop();
                    widget.onAddRootCategory();
                  },
                  onAddChild: (rootId) {
                    Navigator.of(context).pop();
                    widget.onAddChildCategory(rootId);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(
                label: '确定',
                onPressed: _selectedOption == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedOption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
