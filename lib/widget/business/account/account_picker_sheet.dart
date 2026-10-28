import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_inline_action_button.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../icon/business_icon.dart';

Future<String?> showAccountPickerSheet({
  required BuildContext context,
  required List<Account> accounts,
  required String? selectedId,
  String? topActionLabel,
  VoidCallback? onTopAction,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return AccountPickerSheet(
        accounts: accounts,
        selectedId: selectedId,
        topActionLabel: topActionLabel,
        onTopAction: onTopAction,
        onAccountTap: (account) => Navigator.of(context).pop(account.id),
      );
    },
  );
}

class AccountPickerSheetSelection {
  const AccountPickerSheetSelection(this.accountId);

  final String? accountId;
}

Future<AccountPickerSheetSelection?> showOptionalAccountPickerSheet({
  required BuildContext context,
  required List<Account> accounts,
  required String? selectedId,
  required String noneLabel,
}) {
  return showModalBottomSheet<AccountPickerSheetSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return AccountPickerSheet(
        accounts: accounts,
        selectedId: selectedId,
        noneLabel: noneLabel,
        onNoneTap: () =>
            Navigator.of(context).pop(const AccountPickerSheetSelection(null)),
        onAccountTap: (account) =>
            Navigator.of(context).pop(AccountPickerSheetSelection(account.id)),
      );
    },
  );
}

enum _AccountPickerLayout { list, grouped }

class AccountPickerSheet extends StatefulWidget {
  const AccountPickerSheet({
    required this.accounts,
    required this.selectedId,
    required this.onAccountTap,
    super.key,
    this.noneLabel,
    this.onNoneTap,
    this.topActionLabel,
    this.onTopAction,
  });

  final List<Account> accounts;
  final String? selectedId;
  final String? noneLabel;
  final VoidCallback? onNoneTap;
  final String? topActionLabel;
  final VoidCallback? onTopAction;
  final ValueChanged<Account> onAccountTap;

  @override
  State<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<AccountPickerSheet> {
  _AccountPickerLayout _layout = _AccountPickerLayout.list;
  String? _selectedGroupKey;

  @override
  void initState() {
    super.initState();
    _selectedGroupKey = _initialGroupKey(widget.accounts, widget.selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupAccounts(widget.accounts);
    final grouped =
        _layout == _AccountPickerLayout.grouped && groups.isNotEmpty;
    final activeGroup = grouped ? _activeGroup(groups) : null;
    final noneLabel = widget.noneLabel;
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
            if (widget.accounts.isNotEmpty || widget.topActionLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space10,
                  0,
                  AppSpacing.space10,
                  AppSpacing.space4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.accounts.isNotEmpty)
                      Tooltip(
                        message: grouped ? '切换为列表选择' : '切换为分组选择',
                        child: _AccountPickerToolbarButton(
                          key: const ValueKey('account-picker-layout-toggle'),
                          icon: grouped
                              ? RemixIcons.layout_left_line
                              : RemixIcons.list_unordered,
                          label: grouped ? '分组' : '列表',
                          onPressed: _cycleLayout,
                        ),
                      ),
                    if (widget.topActionLabel case final topActionLabel?)
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _AccountPickerToolbarButton(
                            icon: RemixIcons.bank_card_line,
                            label: topActionLabel,
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onTopAction?.call();
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (grouped)
              Flexible(
                child: _buildGroupedLayout(
                  groups: groups,
                  activeGroup: activeGroup!,
                  noneLabel: noneLabel,
                ),
              )
            else
              Flexible(
                child: _AccountPickerAccountList(
                  key: const ValueKey('account-picker-flat-list'),
                  listKey: const ValueKey('account-picker-accounts-list'),
                  accounts: widget.accounts,
                  selectedId: widget.selectedId,
                  noneLabel: noneLabel,
                  onNoneTap: widget.onNoneTap,
                  onAccountTap: widget.onAccountTap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _cycleLayout() {
    setState(() {
      _layout = switch (_layout) {
        _AccountPickerLayout.list => _AccountPickerLayout.grouped,
        _AccountPickerLayout.grouped => _AccountPickerLayout.list,
      };
    });
  }

  Widget _buildGroupedLayout({
    required List<_AccountPickerGroup> groups,
    required _AccountPickerGroup activeGroup,
    required String? noneLabel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final navigationWidth = (constraints.maxWidth * 0.32)
            .clamp(104.0, 124.0)
            .toDouble();
        return Row(
          key: const ValueKey('account-picker-grouped-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space8,
                AppSpacing.space8,
              ),
              child: SizedBox(
                width: navigationWidth,
                child: _AccountPickerGroupNavigation(
                  key: const ValueKey('account-picker-group-navigation'),
                  groups: groups,
                  selectedGroupKey: activeGroup.key,
                  onSelected: (groupKey) =>
                      setState(() => _selectedGroupKey = groupKey),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  AppSpacing.space16,
                  AppSpacing.space8,
                ),
                child: _AccountPickerAccountList(
                  key: const ValueKey('account-picker-grouped-account-list'),
                  listKey: ValueKey(
                    'account-picker-accounts-grouped-${activeGroup.key}',
                  ),
                  accounts: activeGroup.accounts,
                  selectedId: widget.selectedId,
                  noneLabel: noneLabel,
                  onNoneTap: widget.onNoneTap,
                  onAccountTap: widget.onAccountTap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _AccountPickerGroup _activeGroup(List<_AccountPickerGroup> groups) {
    for (final group in groups) {
      if (group.key == _selectedGroupKey) return group;
    }
    return groups.first;
  }
}

class _AccountPickerToolbarButton extends StatelessWidget {
  const _AccountPickerToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppComponentTokens.controlMinHeight,
      ),
      child: AppInlineActionButton(
        icon: icon,
        label: label,
        onPressed: onPressed,
      ),
    );
  }
}

class _AccountPickerGroupNavigation extends StatelessWidget {
  const _AccountPickerGroupNavigation({
    required this.groups,
    required this.selectedGroupKey,
    required this.onSelected,
    super.key,
  });

  final List<_AccountPickerGroup> groups;
  final String selectedGroupKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.space4),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space2),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _AccountPickerGroupItem(
            group: group,
            selected: group.key == selectedGroupKey,
            onTap: () => onSelected(group.key),
          );
        },
      ),
    );
  }
}

class _AccountPickerGroupItem extends StatelessWidget {
  const _AccountPickerGroupItem({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final _AccountPickerGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? colors.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('account-picker-group-${group.key}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppComponentTokens.controlMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
                vertical: AppSpacing.space8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  group.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles
                      .quickActionLabel(selected: selected)
                      .copyWith(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountPickerAccountList extends StatelessWidget {
  const _AccountPickerAccountList({
    required this.listKey,
    required this.accounts,
    required this.selectedId,
    required this.noneLabel,
    required this.onNoneTap,
    required this.onAccountTap,
    super.key,
  });

  final Key listKey;
  final List<Account> accounts;
  final String? selectedId;
  final String? noneLabel;
  final VoidCallback? onNoneTap;
  final ValueChanged<Account> onAccountTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: listKey,
      shrinkWrap: true,
      children: [
        if (noneLabel != null)
          _AccountPickerRow(
            key: const ValueKey('account-picker-none'),
            label: noneLabel!,
            selected: selectedId == null,
            onTap: onNoneTap,
          ),
        for (final account in accounts)
          _AccountPickerRow(
            key: ValueKey('account-picker-account-${account.id}'),
            label: account.name,
            iconKey: account.iconKey,
            selected: account.id == selectedId,
            onTap: () => onAccountTap(account),
          ),
        if (accounts.isEmpty && noneLabel == null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space20),
            child: Text('暂无可选账户', style: context.appTextStyles.inputText),
          ),
      ],
    );
  }
}

class _AccountPickerGroup {
  const _AccountPickerGroup({
    required this.key,
    required this.label,
    required this.accounts,
  });

  final String key;
  final String label;
  final List<Account> accounts;
}

const _otherAccountGroupKey = '__other__';

List<_AccountPickerGroup> _groupAccounts(List<Account> accounts) {
  final accountsByProfile = <AccountProfileKind, List<Account>>{
    for (final profile in AccountProfileKind.values) profile: <Account>[],
  };
  final otherAccounts = <Account>[];
  for (final account in accounts) {
    final profile = AccountProfileKind.fromKey(account.profileKey);
    if (profile == null) {
      otherAccounts.add(account);
    } else {
      accountsByProfile[profile]!.add(account);
    }
  }
  return [
    for (final profile in AccountProfileKind.values)
      if (accountsByProfile[profile]!.isNotEmpty)
        _AccountPickerGroup(
          key: profile.key,
          label: profile.label,
          accounts: List.unmodifiable(accountsByProfile[profile]!),
        ),
    if (otherAccounts.isNotEmpty)
      _AccountPickerGroup(
        key: _otherAccountGroupKey,
        label: '其他账户',
        accounts: List.unmodifiable(otherAccounts),
      ),
  ];
}

String? _initialGroupKey(List<Account> accounts, String? selectedId) {
  for (final account in accounts) {
    if (account.id != selectedId) continue;
    return AccountProfileKind.fromKey(account.profileKey)?.key ??
        _otherAccountGroupKey;
  }
  final groups = _groupAccounts(accounts);
  return groups.isEmpty ? null : groups.first.key;
}

class _AccountPickerRow extends StatelessWidget {
  const _AccountPickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.iconKey,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: AppSpacing.space24,
              child: Center(
                child: iconKey == null
                    ? null
                    : BusinessIcon(
                        iconKey: iconKey,
                        size: AppSpacing.space20,
                        usage: BusinessIconUsage.account,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.formValue,
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
