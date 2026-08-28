import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../../widget/business/icon/business_icon.dart';

class TransactionAllocationOption {
  const TransactionAllocationOption({
    required this.accountId,
    required this.label,
    this.iconKey,
    this.supportingText,
  });

  final String accountId;
  final String label;
  final String? iconKey;
  final String? supportingText;
}

List<TransactionAllocationOption> transactionAllocationOptionsForAccounts(
  Iterable<Account> accounts,
) {
  return [
    for (final account in accounts)
      TransactionAllocationOption(
        accountId: account.id,
        label: account.name,
        iconKey: account.iconKey,
      ),
  ];
}

List<AccountAmountAllocation> transactionAllocationFieldValues({
  required List<AccountAmountAllocation>? allocations,
  required String? fallbackAccountId,
  required Money? total,
}) {
  if (allocations != null) return allocations;
  if (fallbackAccountId == null) return const [];
  return singleAllocation(
    accountId: fallbackAccountId,
    amount: total ?? Money.zero(),
  );
}

Map<String, Money> transactionAllocationMaximums({
  required Iterable<TransactionAllocationOption> options,
  required Iterable<AccountAmountAllocation> availableAllocations,
}) {
  final availableByAccountId = {
    for (final allocation in availableAllocations)
      allocation.accountId: allocation.amount,
  };
  return {
    for (final option in options)
      option.accountId: availableByAccountId[option.accountId] ?? Money.zero(),
  };
}

typedef TransactionAllocationOptionSelector =
    Future<TransactionAllocationOption?> Function(
      BuildContext context,
      String? selectedAccountId,
      List<TransactionAllocationOption> options,
    );

Future<TransactionAllocationOption?> selectTransactionAllocationAccount(
  BuildContext context, {
  required List<Account> accounts,
  required String? selectedAccountId,
  required List<TransactionAllocationOption> options,
}) async {
  final optionIds = {for (final option in options) option.accountId};
  final selected = await showAccountPickerSheet(
    context: context,
    title: '选择账户',
    accounts: [
      for (final account in accounts)
        if (optionIds.contains(account.id)) account,
    ],
    selectedId: selectedAccountId,
  );
  if (selected == null) return null;
  return options.where((option) => option.accountId == selected).firstOrNull;
}

/// Displays every eligible category or account directly in the current form.
/// Empty amounts are omitted from the emitted allocation list.
class TransactionAllocationAmountFields extends StatelessWidget {
  const TransactionAllocationAmountFields({
    required this.title,
    required this.allocations,
    required this.options,
    required this.onChanged,
    super.key,
    this.expectedTotal,
    this.maximumByAccountId = const {},
    this.statusInHeader = true,
  });

  final String title;
  final List<AccountAmountAllocation> allocations;
  final List<TransactionAllocationOption> options;
  final Money? expectedTotal;
  final Map<String, Money> maximumByAccountId;
  final bool statusInHeader;
  final ValueChanged<List<AccountAmountAllocation>> onChanged;

  @override
  Widget build(BuildContext context) {
    final amountsByAccountId = {
      for (final allocation in allocations)
        allocation.accountId: allocation.amount,
    };
    final allocated = sumAllocations(allocations);
    return _AllocationSurface(
      title: title,
      itemCount: options.length,
      allocated: allocated,
      expectedTotal: expectedTotal,
      statusInHeader: statusInHeader,
      child: options.isEmpty
          ? SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  '暂无可用选项',
                  style: context.appTextStyles.listSupporting,
                ),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  _AllocationAmountRow(
                    key: ValueKey(
                      'inline-allocation-${options[index].accountId}',
                    ),
                    option: options[index],
                    amount:
                        amountsByAccountId[options[index].accountId] ??
                        Money.zero(),
                    maximum: maximumByAccountId[options[index].accountId],
                    amountRequired: false,
                    onAmountChanged: (amount) =>
                        _updateAmount(options[index].accountId, amount),
                  ),
                  if (index < options.length - 1)
                    const SizedBox(height: AppSpacing.space6),
                ],
              ],
            ),
    );
  }

  void _updateAmount(String accountId, Money amount) {
    final amountsByAccountId = {
      for (final allocation in allocations)
        allocation.accountId: allocation.amount,
    };
    if (amount.minorUnits > 0) {
      amountsByAccountId[accountId] = amount;
    } else {
      amountsByAccountId.remove(accountId);
    }
    onChanged([
      for (final option in options)
        if (amountsByAccountId[option.accountId] case final amount?)
          AccountAmountAllocation(accountId: option.accountId, amount: amount),
    ]);
  }
}

class TransactionInlineAllocationColumn extends StatelessWidget {
  const TransactionInlineAllocationColumn({
    required this.title,
    required this.allocations,
    required this.options,
    required this.addLabel,
    required this.onSelectOption,
    required this.onChanged,
    super.key,
    this.expectedTotal,
    this.statusInHeader = true,
  });

  final String title;
  final List<AccountAmountAllocation> allocations;
  final List<TransactionAllocationOption> options;
  final String addLabel;
  final Money? expectedTotal;
  final bool statusInHeader;
  final TransactionAllocationOptionSelector onSelectOption;
  final ValueChanged<List<AccountAmountAllocation>> onChanged;

  @override
  Widget build(BuildContext context) {
    final availableOptions = options
        .where(
          (option) => !allocations.any(
            (allocation) => allocation.accountId == option.accountId,
          ),
        )
        .toList(growable: false);
    return _AllocationSurface(
      title: title,
      itemCount: allocations.length,
      allocated: sumAllocations(allocations),
      expectedTotal: expectedTotal,
      statusInHeader: statusInHeader,
      footer: TextButton.icon(
        onPressed: availableOptions.isEmpty
            ? null
            : () => _add(context, availableOptions),
        icon: const Icon(RemixIcons.add_line),
        label: Text(addLabel),
      ),
      child: allocations.isEmpty
          ? SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  '暂无$title',
                  style: context.appTextStyles.listSupporting,
                ),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < allocations.length; index++) ...[
                  _AllocationAmountRow(
                    key: ValueKey(
                      'inline-allocation-${allocations[index].accountId}',
                    ),
                    option: _optionOf(allocations[index].accountId),
                    amount: allocations[index].amount,
                    amountRequired: true,
                    onOptionTap: () => _changeOption(context, index),
                    onAmountChanged: (amount) {
                      final next = List<AccountAmountAllocation>.of(
                        allocations,
                      );
                      next[index] = allocations[index].copyWith(amount: amount);
                      onChanged(next);
                    },
                    onDelete: () {
                      final next = List<AccountAmountAllocation>.of(allocations)
                        ..removeAt(index);
                      onChanged(next);
                    },
                  ),
                  if (index < allocations.length - 1)
                    const SizedBox(height: AppSpacing.space6),
                ],
              ],
            ),
    );
  }

  TransactionAllocationOption _optionOf(String accountId) {
    return options.firstWhere(
      (option) => option.accountId == accountId,
      orElse: () =>
          TransactionAllocationOption(accountId: accountId, label: accountId),
    );
  }

  Future<void> _add(
    BuildContext context,
    List<TransactionAllocationOption> availableOptions,
  ) async {
    final option = await onSelectOption(context, null, availableOptions);
    if (option == null || !context.mounted) return;
    onChanged([
      ...allocations,
      AccountAmountAllocation(
        accountId: option.accountId,
        amount: Money.zero(),
      ),
    ]);
  }

  Future<void> _changeOption(BuildContext context, int index) async {
    final allocation = allocations[index];
    final usedByOtherRows = {
      for (var otherIndex = 0; otherIndex < allocations.length; otherIndex++)
        if (otherIndex != index) allocations[otherIndex].accountId,
    };
    final selectableOptions = options
        .where((option) => !usedByOtherRows.contains(option.accountId))
        .toList(growable: false);
    final option = await onSelectOption(
      context,
      allocation.accountId,
      selectableOptions,
    );
    if (option == null ||
        option.accountId == allocation.accountId ||
        !context.mounted) {
      return;
    }
    onChanged(
      replaceAllocationAccount(
        allocations: allocations,
        sourceAccountId: allocation.accountId,
        targetAccountId: option.accountId,
      ),
    );
  }
}

class _AllocationSurface extends StatelessWidget {
  const _AllocationSurface({
    required this.title,
    required this.itemCount,
    required this.allocated,
    required this.expectedTotal,
    required this.child,
    this.footer,
    this.statusInHeader = false,
  });

  final String title;
  final int itemCount;
  final Money allocated;
  final Money? expectedTotal;
  final Widget child;
  final Widget? footer;
  final bool statusInHeader;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      borderRadius: AppRadius.radiusMd,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: context.appTextStyles.formLabel),
                ),
                Text(
                  '$itemCount项',
                  style: context.appTextStyles.listSupporting.copyWith(
                    color: colors.primary,
                  ),
                ),
                if (statusInHeader) ...[
                  const SizedBox(width: AppSpacing.space8),
                  _AllocationStatus(
                    allocated: allocated,
                    expectedTotal: expectedTotal,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
            child,
            if (footer case final footer?) ...[
              const SizedBox(height: AppSpacing.space6),
              footer,
            ],
            if (!statusInHeader) ...[
              const SizedBox(height: AppSpacing.space2),
              _AllocationStatus(
                allocated: allocated,
                expectedTotal: expectedTotal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllocationAmountRow extends StatefulWidget {
  const _AllocationAmountRow({
    required this.option,
    required this.amount,
    required this.amountRequired,
    required this.onAmountChanged,
    super.key,
    this.maximum,
    this.onOptionTap,
    this.onDelete,
  });

  final TransactionAllocationOption option;
  final Money amount;
  final Money? maximum;
  final bool amountRequired;
  final VoidCallback? onOptionTap;
  final ValueChanged<Money> onAmountChanged;
  final VoidCallback? onDelete;

  @override
  State<_AllocationAmountRow> createState() => _AllocationAmountRowState();
}

class _AllocationAmountRowState extends State<_AllocationAmountRow> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _amountText(widget.amount));
    _amountFocusNode = FocusNode()..addListener(_handleAmountFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _AllocationAmountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_amountFocusNode.hasFocus && oldWidget.amount != widget.amount) {
      _syncAmountText();
    }
  }

  @override
  void dispose() {
    _amountFocusNode
      ..removeListener(_handleAmountFocusChanged)
      ..dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.space48),
        child: Row(
          children: [
            Expanded(child: _buildOption(context)),
            SizedBox(
              width: 96,
              child: AppPlainTextFormField(
                key: ValueKey('allocation-amount-${widget.option.accountId}'),
                controller: _amountController,
                focusNode: _amountFocusNode,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [moneyInputFormatter],
                validator: _validateAmount,
                textAlign: TextAlign.end,
                style: context.appTextStyles.formValueEmphasis,
                onChanged: (value) => widget.onAmountChanged(
                  Money.tryParse(value) ?? Money.zero(),
                ),
              ),
            ),
            if (widget.onDelete case final onDelete?)
              IconButton(
                onPressed: onDelete,
                tooltip: '删除分配',
                visualDensity: VisualDensity.compact,
                icon: const Icon(RemixIcons.close_line, size: 18),
              )
            else
              const SizedBox(width: AppSpacing.space8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space12,
      ),
      child: Row(
        children: [
          BusinessIcon(iconKey: widget.option.iconKey, size: 20),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              widget.option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.formValue,
            ),
          ),
        ],
      ),
    );
    final onTap = widget.onOptionTap;
    if (onTap == null) return content;
    return InkWell(
      key: ValueKey('allocation-option-${widget.option.accountId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: content,
    );
  }

  String? _validateAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (!widget.amountRequired && trimmed.isEmpty) return null;
    final amount = Money.tryParse(trimmed);
    if (amount == null || amount.minorUnits <= 0) {
      return widget.amountRequired ? '请输入有效金额' : null;
    }
    final maximum = widget.maximum;
    if (maximum != null && amount.minorUnits > maximum.minorUnits) {
      return '不能超过可分配金额';
    }
    return null;
  }

  void _handleAmountFocusChanged() {
    if (!_amountFocusNode.hasFocus) _syncAmountText();
  }

  void _syncAmountText() {
    final text = _amountText(widget.amount);
    if (_amountController.text == text) return;
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _AllocationStatus extends StatelessWidget {
  const _AllocationStatus({
    required this.allocated,
    required this.expectedTotal,
  });

  final Money allocated;
  final Money? expectedTotal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (expectedTotal) {
      null => (
        '合计 ${formatMoney(allocated, style: MoneyFormatStyle.plain)}',
        colors.onSurfaceVariant,
      ),
      final total when total == allocated => ('已匹配', colors.primary),
      final total when total.minorUnits > allocated.minorUnits => (
        '待分配 ${formatMoney(total - allocated, style: MoneyFormatStyle.plain)}',
        colors.error,
      ),
      final total => (
        '超出 ${formatMoney(allocated - total, style: MoneyFormatStyle.plain)}',
        colors.error,
      ),
    };
    return Text(
      label,
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.appTextStyles.listSupporting.copyWith(color: color),
    );
  }
}

String _amountText(Money amount) {
  return amount.minorUnits == 0
      ? ''
      : formatMoney(amount, style: MoneyFormatStyle.plain);
}
