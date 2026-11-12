part of 'transaction_form_page.dart';

class _TransactionMetadataActionRow extends StatelessWidget {
  const _TransactionMetadataActionRow({
    required this.allocated,
    required this.showEntryMode,
    required this.counterpartyName,
    required this.tagNames,
    required this.onSelectCounterparty,
    required this.onSelectTags,
    required this.onToggleMode,
  });

  final bool allocated;
  final bool showEntryMode;
  final String? counterpartyName;
  final List<String> tagNames;
  final VoidCallback onSelectCounterparty;
  final VoidCallback onSelectTags;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final counterparty = counterpartyName == null
        ? _QuickActionChip(
            key: const ValueKey('transaction-counterparty-action'),
            label: '对手方',
            selected: false,
            onTap: onSelectCounterparty,
          )
        : InkWell(
            key: const ValueKey('transaction-counterparty-action'),
            onTap: onSelectCounterparty,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: CounterpartyBadge(name: counterpartyName!),
            ),
          );
    final tags = tagNames.isEmpty
        ? _QuickActionChip(label: '标签', selected: false, onTap: onSelectTags)
        : InkWell(
            onTap: onSelectTags,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Wrap(
                spacing: AppSpacing.space4,
                runSpacing: AppSpacing.space4,
                children: [for (final name in tagNames) TagBadge(name: name)],
              ),
            ),
          );
    return Row(
      key: const ValueKey('transaction-metadata-action-row'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(flex: 2, child: counterparty),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                flex: 3,
                child: Align(alignment: Alignment.centerLeft, child: tags),
              ),
            ],
          ),
        ),
        if (showEntryMode) ...[
          const SizedBox(width: AppSpacing.space8),
          _QuickActionChip(
            key: const ValueKey('toggle-transaction-entry-mode'),
            icon: RemixIcons.list_check_3,
            label: '分项',
            selected: allocated,
            onTap: onToggleMode,
          ),
        ],
      ],
    );
  }
}

class _MainAccountPickerSection extends StatelessWidget {
  const _MainAccountPickerSection({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(children: children),
      ),
    );
  }
}

class _MainAccountPickerTile extends StatelessWidget {
  const _MainAccountPickerTile({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    required this.validator,
    super.key,
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final effective = effectiveAccount(selectedId, accounts);
    final title = effective?.name ?? '$label为空';

    return AppControlledFormField<String>(
      value: effective?.id,
      onChanged: onChanged,
      validator: validator,
      builder: (context, _, errorText, changeValue) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: InkWell(
                onTap: () => _showAccountSheet(context, changeValue),
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                    vertical: AppSpacing.space12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppSpacing.space32,
                        child: Center(
                          child: BusinessIcon(
                            iconRef: effective?.iconKey,
                            size: 28,
                            usage: BusinessIconUsage.account,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: textStyles.formLabel),
                            const SizedBox(height: AppSpacing.space2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textStyles.formValue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (errorText != null) _FormFieldErrorText(errorText),
          ],
        );
      },
    );
  }

  Future<void> _showAccountSheet(
    BuildContext context,
    ValueChanged<String?> changeValue,
  ) async {
    final selected = await showAccountPickerSheet(
      context: context,
      accounts: accounts,
      selectedId: effectiveAccount(selectedId, accounts)?.id,
    );
    if (selected == null) return;
    changeValue(selected);
  }
}

class _TransferActualOutflowSummary extends StatelessWidget {
  const _TransferActualOutflowSummary({
    required this.amountController,
    required this.feeController,
    required this.discountController,
  });

  final TextEditingController amountController;
  final TextEditingController feeController;
  final TextEditingController discountController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        amountController,
        feeController,
        discountController,
      ]),
      builder: (context, _) {
        final amount = Money.tryParse(amountController.text);
        if (amount == null || amount.minorUnits <= 0) {
          return const SizedBox.shrink();
        }
        final fee = Money.tryParse(feeController.text) ?? Money.zero();
        final discount =
            Money.tryParse(discountController.text) ?? Money.zero();
        final actualOutflow = amount + fee - discount;
        return Padding(
          key: const ValueKey('transfer-actual-outflow-summary'),
          padding: const EdgeInsets.only(top: AppSpacing.space8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '实际扣款 ${actualOutflow.format()}',
              style: context.appTextStyles.formSupporting.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

String? _validateTransferDiscountValue(
  String? value, {
  required String amountText,
  required String feeText,
}) {
  final amountError = validateOptionalNonNegativeMoneyText(value);
  if (amountError != null) return amountError;
  final amount = Money.tryParse(amountText);
  final discount = Money.tryParse(value);
  if (amount != null &&
      discount != null &&
      discount.minorUnits > amount.minorUnits) {
    return '不能超过转账金额';
  }
  if (amount != null && discount != null) {
    final fee = Money.tryParse(feeText) ?? Money.zero();
    if ((amount + fee - discount).minorUnits <= 0) {
      return '实际扣款必须大于 0';
    }
  }
  return null;
}

class _MainTransferAdjustmentTile extends StatelessWidget {
  const _MainTransferAdjustmentTile({
    required this.label,
    required this.icon,
    required this.controller,
    required this.validator,
    super.key,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: AppSpacing.space32,
              child: Center(child: Icon(icon, size: 28)),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textStyles.formLabel),
                  const SizedBox(height: AppSpacing.space2),
                  AppPlainTextFormField(
                    controller: controller,
                    hintText: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [moneyInputFormatter],
                    validator: validator,
                    textAlign: TextAlign.left,
                    style: textStyles.formValue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormFieldErrorText extends StatelessWidget {
  const _FormFieldErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.space8,
        top: AppSpacing.space4,
        bottom: AppSpacing.space4,
      ),
      child: Text(
        message,
        style: context.appTextStyles.formLabel.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
