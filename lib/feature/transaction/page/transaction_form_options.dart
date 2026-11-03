part of 'transaction_form_page.dart';

class _TransactionOptionsPanel extends StatelessWidget {
  const _TransactionOptionsPanel({
    required this.mode,
    required this.occurredAt,
    required this.moneyAccounts,
    required this.installmentAccounts,
    required this.amortization,
    required this.amortizationConfiguration,
    required this.amortizationDeferralAccounts,
    required this.advanceAccounts,
    required this.fromAccountId,
    required this.toAccountId,
    required this.advanceReceivableAccountId,
    required this.amortizationDeferralAccountId,
    required this.expenseScene,
    required this.consumptionInstallment,
    required this.aaPeopleCount,
    required this.allocatedEntry,
    required this.excludeStats,
    required this.excludeBudget,
    required this.onPickDate,
    required this.onFromAccountChanged,
    required this.onInstallmentConfiguration,
    required this.onAmortizationConfiguration,
    required this.onAmortizationDeferralAccountChanged,
    required this.onToAccountChanged,
    required this.onAdvanceAccountChanged,
    required this.onAaPeopleTap,
    required this.onExcludeStatsChanged,
    required this.onExcludeBudgetChanged,
  });

  final TransactionFormMode mode;
  final DateTime occurredAt;
  final List<Account> moneyAccounts;
  final List<Account> installmentAccounts;
  final bool amortization;
  final bool amortizationConfiguration;
  final List<Account> amortizationDeferralAccounts;
  final List<Account> advanceAccounts;
  final String? fromAccountId;
  final String? toAccountId;
  final String? advanceReceivableAccountId;
  final String? amortizationDeferralAccountId;
  final TransactionExpenseScene expenseScene;
  final bool consumptionInstallment;
  final int aaPeopleCount;
  final bool allocatedEntry;
  final bool excludeStats;
  final bool excludeBudget;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onFromAccountChanged;
  final VoidCallback onInstallmentConfiguration;
  final VoidCallback onAmortizationConfiguration;
  final ValueChanged<String?> onAmortizationDeferralAccountChanged;
  final ValueChanged<String?> onToAccountChanged;
  final ValueChanged<String?> onAdvanceAccountChanged;
  final VoidCallback onAaPeopleTap;
  final ValueChanged<bool> onExcludeStatsChanged;
  final ValueChanged<bool> onExcludeBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final showPrimaryAccount =
        (mode == TransactionFormMode.expense ||
            mode == TransactionFormMode.income) &&
        (!allocatedEntry || consumptionInstallment);
    final showExcludeStats =
        mode == TransactionFormMode.expense ||
        mode == TransactionFormMode.income ||
        mode == TransactionFormMode.transfer;
    final accountLabel = consumptionInstallment
        ? '分期账户'
        : mode == TransactionFormMode.income
        ? '收入账户'
        : '支出账户';
    final primaryAccounts = consumptionInstallment
        ? installmentAccounts
        : moneyAccounts;
    final primaryAccountId = mode == TransactionFormMode.income
        ? toAccountId
        : fromAccountId;
    final primaryChanged = mode == TransactionFormMode.income
        ? onToAccountChanged
        : onFromAccountChanged;

    Widget buildPanel(ValueChanged<String?> accountChanged, String? errorText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _QuickActionChip(
                    label: _formatDateTime(occurredAt),
                    selected: false,
                    onTap: onPickDate,
                  ),
                  if (showPrimaryAccount)
                    _AccountSelectorChip(
                      key: consumptionInstallment
                          ? const ValueKey(
                              'consumption-installment-account-option',
                            )
                          : mode == TransactionFormMode.expense
                          ? const ValueKey('expense-primary-account-option')
                          : null,
                      label: accountLabel,
                      accounts: primaryAccounts,
                      selectedId: primaryAccountId,
                      onChanged: accountChanged,
                    ),
                  if (consumptionInstallment)
                    _QuickActionChip(
                      key: const ValueKey(
                        'consumption-installment-configuration',
                      ),
                      icon: RemixIcons.settings_3_line,
                      label: '分期配置',
                      selected: false,
                      onTap: onInstallmentConfiguration,
                    ),
                  if (amortization)
                    _AccountSelectorChip(
                      key: const ValueKey(
                        'amortization-deferral-account-option',
                      ),
                      label: mode == TransactionFormMode.expense
                          ? '预付账户'
                          : '预收账户',
                      accounts: amortizationDeferralAccounts,
                      selectedId: amortizationDeferralAccountId,
                      onChanged: onAmortizationDeferralAccountChanged,
                    ),
                  if (amortizationConfiguration)
                    _QuickActionChip(
                      key: const ValueKey('amortization-configuration'),
                      icon: RemixIcons.settings_3_line,
                      label: '摊销配置',
                      selected: false,
                      onTap: onAmortizationConfiguration,
                    ),
                  if (mode == TransactionFormMode.expense &&
                      expenseScene.isAdvance)
                    _AccountSelectorChip(
                      key: const ValueKey('advance-account-option'),
                      label: expenseScene.accountLabel,
                      accounts: advanceAccounts,
                      selectedId: advanceReceivableAccountId,
                      allowNone: true,
                      noneLabel: expenseScene.noneLabel,
                      onChanged: onAdvanceAccountChanged,
                    ),
                  if (mode == TransactionFormMode.expense && expenseScene.isAa)
                    _QuickActionChip(
                      key: const ValueKey('aa-people-action'),
                      icon: RemixIcons.user_shared_line,
                      label: '$aaPeopleCount人',
                      selected: false,
                      onTap: onAaPeopleTap,
                    ),
                  if (showExcludeStats)
                    _ToggleChip(
                      icon: Icons.remove_circle_outline,
                      label: '不计收支',
                      selected: excludeStats,
                      onChanged: onExcludeStatsChanged,
                    ),
                  if (mode == TransactionFormMode.expense ||
                      mode == TransactionFormMode.transfer)
                    _ToggleChip(
                      icon: Icons.pie_chart_outline,
                      label: '不计预算',
                      selected: excludeBudget,
                      onChanged: onExcludeBudgetChanged,
                    ),
                ],
              ),
            ),
          ),
          if (errorText != null) _FormFieldErrorText(errorText),
        ],
      );
    }

    if (!showPrimaryAccount) return buildPanel(primaryChanged, null);

    return AppControlledFormField<String>(
      value: effectiveAccountId(primaryAccountId, primaryAccounts),
      onChanged: primaryChanged,
      validator: (value) => value == null ? '请选择$accountLabel' : null,
      builder: (context, _, errorText, changeValue) =>
          buildPanel(changeValue, errorText),
    );
  }
}

class _AccountSelectorChip extends StatelessWidget {
  const _AccountSelectorChip({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    super.key,
    this.allowNone = false,
    this.noneLabel = '无',
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == null
        ? null
        : accounts.where((account) => account.id == selectedId).firstOrNull;
    final effective =
        selected ?? (allowNone ? null : effectiveAccount(null, accounts));
    final showsNone = allowNone && selected == null;
    final text = showsNone
        ? noneLabel
        : effective == null
        ? '$label为空'
        : effective.name;
    final leading = effective == null
        ? null
        : BusinessIcon(
            iconKey: effective.iconKey,
            size: 14,
            usage: BusinessIconUsage.account,
          );

    return _QuickActionChip(
      label: text,
      leading: leading,
      selected: false,
      onTap: () => _showAccountSheet(context),
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    if (allowNone) {
      final selected = await showOptionalAccountPickerSheet(
        context: context,
        accounts: accounts,
        selectedId: selectedId,
        noneLabel: noneLabel,
      );
      if (selected == null) return;
      onChanged(selected.accountId);
      return;
    }

    final selected = await showAccountPickerSheet(
      context: context,
      accounts: accounts,
      selectedId: effectiveAccount(selectedId, accounts)?.id,
    );
    if (selected == null) return;
    onChanged(selected);
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuickActionChip(
      icon: icon,
      label: label,
      selected: selected,
      onTap: () => onChanged(!selected),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    super.key,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.space2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.08)
                : AppColors.neutral99,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.space2),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.space2),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles
                      .quickActionLabel(selected: selected)
                      .copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
