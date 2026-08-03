import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../application/ledger/ledger_query_api.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../presentation/account_section_presentation.dart';
import '../view_model/account_view.dart';
import '../view_model/account_organization_view_model.dart';
import '../view_model/account_views_provider.dart';
import '../view_model/asset_section_collapse_view_model.dart';
import '../widget/account_list_row.dart';
import '../../shared/view_model/ui_action_outcome.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _hideBalances = false;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountViewsProvider);
    final archivedAccountsAsync = ref.watch(archivedAccountViewsProvider);
    final groupsAsync = ref.watch(accountGroupsProvider);
    final balanceSheetAsync = ref.watch(balanceSheetComparisonProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: switch ((
          accountsAsync,
          archivedAccountsAsync,
          groupsAsync,
          balanceSheetAsync,
        )) {
          (
            AsyncData(value: final accounts),
            AsyncData(value: final archivedAccounts),
            AsyncData(value: final groups),
            AsyncData(value: final balanceSheet),
          ) =>
            _AccountsContent(
              accounts: accounts,
              archivedAccounts: archivedAccounts,
              groups: groups,
              balanceSheet: balanceSheet,
              hideBalances: _hideBalances,
              onToggleHide:
                  () => setState(() => _hideBalances = !_hideBalances),
            ),
          (AsyncError(:final error), _, _, _) ||
          (_, AsyncError(:final error), _, _) ||
          (_, _, AsyncError(:final error), _) ||
          (
            _,
            _,
            _,
            AsyncError(:final error),
          ) => _AccountsErrorView(error: error),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _AccountsContent extends ConsumerWidget {
  const _AccountsContent({
    required this.accounts,
    required this.archivedAccounts,
    required this.groups,
    required this.balanceSheet,
    required this.hideBalances,
    required this.onToggleHide,
  });

  final List<AccountView> accounts;
  final List<AccountView> archivedAccounts;
  final List<AccountGroup> groups;
  final BalanceSheetComparison balanceSheet;
  final bool hideBalances;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = buildActiveAccountSections(accounts, groups);
    final collapsedKeys =
        ref.watch(assetSectionCollapseViewModelProvider).value ??
        const <String>{};
    final allCollapsed =
        sections.isNotEmpty &&
        sections.every((section) => collapsedKeys.contains(section.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space24,
        AppSpacing.space20,
        AppSpacing.space48 + AppSpacing.space48,
      ),
      children: [
        _AssetsHeader(
          hideBalances: hideBalances,
          onToggleHide: onToggleHide,
          allCollapsed: sections.isEmpty ? null : allCollapsed,
          onToggleCollapseAll: () {
            final viewModel = ref.read(
              assetSectionCollapseViewModelProvider.notifier,
            );
            if (allCollapsed) {
              viewModel.expandAll();
            } else {
              viewModel.collapseAll([
                for (final section in sections) section.id,
              ]);
            }
          },
          onManageGroups: () => _showAccountGroupManagerSheet(context, ref),
        ),
        const SizedBox(height: AppSpacing.space18),
        _NetAssetCard(comparison: balanceSheet, hideBalances: hideBalances),
        if (sections.isEmpty) ...[
          const SizedBox(height: AppSpacing.space24),
          const _EmptyAccountsHint(),
        ],
        for (var index = 0; index < sections.length; index++) ...[
          SizedBox(
            height: index == 0 ? AppSpacing.space28 : AppSpacing.space20,
          ),
          _AccountSection(
            section: sections[index],
            hideBalances: hideBalances,
            collapsed: collapsedKeys.contains(sections[index].id),
            onToggleCollapsed:
                () => ref
                    .read(assetSectionCollapseViewModelProvider.notifier)
                    .toggle(sections[index].id),
            onAccountDropped:
                (account, insertAt) => _moveAccount(
                  context,
                  ref,
                  account: account,
                  section: sections[index],
                  insertAt: insertAt,
                ),
            onGroupDropped:
                (draggedSection) => _reorderSection(
                  context,
                  ref,
                  groups: groups,
                  draggedSection: draggedSection,
                  targetSection: sections[index],
                ),
          ),
        ],
        if (archivedAccounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space20),
          _ArchivedAccountsEntry(
            count: archivedAccounts.length,
            onTap: () => context.push('/account/archived', extra: hideBalances),
          ),
        ],
      ],
    );
  }
}

Future<void> _moveAccount(
  BuildContext context,
  WidgetRef ref, {
  required AccountView account,
  required AccountSectionPresentation section,
  required int insertAt,
}) async {
  final outcome = await ref
      .read(accountOrganizationViewModelProvider.notifier)
      .moveAccount(
        accountId: account.id,
        targetGroupId: section.id == 'ungrouped' ? null : section.id,
        targetAccountIds: [for (final item in section.accounts) item.id],
        insertAt: insertAt,
      );
  if (!context.mounted || outcome is UiActionSuccess<void>) return;
  final failure = outcome as UiActionFailure<void>;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(failure.error.message)));
}

Future<void> _reorderSection(
  BuildContext context,
  WidgetRef ref, {
  required List<AccountGroup> groups,
  required AccountSectionPresentation draggedSection,
  required AccountSectionPresentation targetSection,
}) async {
  if (draggedSection.id == targetSection.id ||
      draggedSection.id == 'ungrouped' ||
      targetSection.id == 'ungrouped') {
    return;
  }
  final orderedIds = [for (final group in groups) group.id]
    ..remove(draggedSection.id);
  final targetIndex = orderedIds.indexOf(targetSection.id);
  if (targetIndex < 0) return;
  orderedIds.insert(targetIndex, draggedSection.id);
  final outcome = await ref
      .read(accountOrganizationViewModelProvider.notifier)
      .reorderGroups(orderedIds);
  if (!context.mounted || outcome is UiActionSuccess<void>) return;
  final failure = outcome as UiActionFailure<void>;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(failure.error.message)));
}

class _AssetsHeader extends StatelessWidget {
  const _AssetsHeader({
    required this.hideBalances,
    required this.onToggleHide,
    required this.allCollapsed,
    required this.onToggleCollapseAll,
    required this.onManageGroups,
  });

  final bool hideBalances;
  final VoidCallback onToggleHide;

  /// null 表示没有可折叠的分组，不显示折叠按钮。
  final bool? allCollapsed;
  final VoidCallback onToggleCollapseAll;
  final VoidCallback onManageGroups;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allCollapsed = this.allCollapsed;
    return Row(
      children: [
        Text('资产', style: context.appTextStyles.pageTitle),
        const Spacer(),
        if (allCollapsed != null)
          IconButton(
            onPressed: onToggleCollapseAll,
            icon: Icon(
              allCollapsed
                  ? RemixIcons.expand_up_down_line
                  : RemixIcons.contract_up_down_line,
              color: colors.onSurfaceVariant,
            ),
            tooltip: allCollapsed ? '展开全部分组' : '折叠全部分组',
          ),
        IconButton(
          onPressed: () => context.push('/account/new'),
          icon: Icon(RemixIcons.add_line, color: colors.onSurface),
          tooltip: '新建账户',
        ),
        AppPopupMenuButton<_AssetsHeaderAction>(
          tooltip: '更多操作',
          icon: RemixIcons.more_2_fill,
          options: [
            const AppPopupMenuOption(
              value: _AssetsHeaderAction.manageGroups,
              label: '管理分组',
              icon: RemixIcons.folder_settings_line,
            ),
            AppPopupMenuOption(
              value: _AssetsHeaderAction.toggleBalanceVisibility,
              label: hideBalances ? '显示余额' : '隐藏余额',
              icon:
                  hideBalances ? RemixIcons.eye_line : RemixIcons.eye_off_line,
            ),
          ],
          onSelected: (action) {
            switch (action) {
              case _AssetsHeaderAction.manageGroups:
                onManageGroups();
              case _AssetsHeaderAction.toggleBalanceVisibility:
                onToggleHide();
            }
          },
        ),
      ],
    );
  }
}

enum _AssetsHeaderAction { manageGroups, toggleBalanceVisibility }

class _NetAssetCard extends StatelessWidget {
  const _NetAssetCard({required this.comparison, required this.hideBalances});

  final BalanceSheetComparison comparison;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final assets = comparison.current.assets;
    final liabilities = comparison.current.liabilities;
    final assetMinor = assets.minorUnits;
    final liabilityMinor = liabilities.minorUnits;
    final netMinor = assetMinor - liabilityMinor;
    final totalForRatio = (assetMinor.abs() + liabilityMinor.abs()).clamp(
      1,
      1 << 62,
    );
    final assetRatio = assetMinor.abs() / totalForRatio;
    final liabilityRatio = liabilityMinor.abs() / totalForRatio;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        gradient: LinearGradient(
          colors: [colors.primary.withValues(alpha: 0.92), colors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: context.appTextStyles.onPrimaryLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('净资产（元）', style: textStyles.onPrimaryLabel),
                        const SizedBox(width: AppSpacing.space6),
                        Icon(
                          RemixIcons.eye_line,
                          size: 16,
                          color: colors.onPrimary.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space14),
                    Text(
                      hideBalances ? '¥ **,***.**' : _formatMoney(netMinor),
                      style: textStyles.amountDisplay.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    Text(
                      hideBalances
                          ? '较上月 ****'
                          : _formatNetAssetComparison(
                            comparison.netAssetChange,
                          ),
                      style: textStyles.onPrimarySupporting,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 142,
              child: Column(
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: CustomPaint(
                      painter: _AssetDonutPainter(
                        assetRatio: assetRatio,
                        liabilityRatio: liabilityRatio,
                        baseColor: colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space10),
                  _LegendRow(
                    key: const ValueKey('asset-balance-legend'),
                    label: '资产',
                    money: assets,
                    hideBalance: hideBalances,
                    color: colors.onPrimary.withValues(alpha: 0.72),
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  _LegendRow(
                    key: const ValueKey('liability-balance-legend'),
                    label: '负债',
                    money: liabilities,
                    hideBalance: hideBalances,
                    color: colors.onPrimary.withValues(alpha: 0.42),
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

class _AssetDonutPainter extends CustomPainter {
  const _AssetDonutPainter({
    required this.assetRatio,
    required this.liabilityRatio,
    required this.baseColor,
  });

  final double assetRatio;
  final double liabilityRatio;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.22;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
    paint.color = baseColor.withValues(alpha: 0.22);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 6.283, false, paint);
    paint.color = baseColor.withValues(alpha: 0.72);
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.57,
      6.283 * assetRatio,
      false,
      paint,
    );
    paint.color = baseColor.withValues(alpha: 0.42);
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.57 + 6.283 * assetRatio,
      6.283 * liabilityRatio,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AssetDonutPainter oldDelegate) {
    return oldDelegate.assetRatio != assetRatio ||
        oldDelegate.liabilityRatio != liabilityRatio ||
        oldDelegate.baseColor != baseColor;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.money,
    required this.hideBalance,
    required this.color,
    super.key,
  });

  final String label;
  final Money money;
  final bool hideBalance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.space6),
        Expanded(flex: 1, child: Text(label, style: textStyles.onPrimaryTiny)),
        const SizedBox(width: AppSpacing.space4),
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hiddenText = '¥ ****';
              return AdaptiveMoneyText(
                preciseText: hideBalance ? hiddenText : money.format(),
                compactText:
                    hideBalance
                        ? hiddenText
                        : formatMoney(money, style: MoneyFormatStyle.compact),
                style: textStyles.onPrimaryTinyStrong,
                maxWidth: constraints.maxWidth,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.section,
    required this.hideBalances,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onAccountDropped,
    required this.onGroupDropped,
  });

  final AccountSectionPresentation section;
  final bool hideBalances;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final void Function(AccountView account, int insertAt) onAccountDropped;
  final ValueChanged<AccountSectionPresentation> onGroupDropped;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final accounts = section.accounts;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space4,
        ),
        child: Column(
          children: [
            DragTarget<AccountSectionPresentation>(
              onWillAcceptWithDetails:
                  (details) =>
                      section.id != 'ungrouped' &&
                      details.data.id != 'ungrouped' &&
                      details.data.id != section.id,
              onAcceptWithDetails: (details) => onGroupDropped(details.data),
              builder:
                  (
                    context,
                    candidateData,
                    child,
                  ) => Draggable<AccountSectionPresentation>(
                    data: section,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.88,
                        child: Text(
                          section.title,
                          style: textStyles.groupTitle,
                        ),
                      ),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                        onTap: onToggleCollapsed,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSpacing.space48,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (candidateData.isNotEmpty)
                                Container(
                                  height: 3,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      section.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textStyles.groupTitle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space12),
                                  AccountAmountText(
                                    money: section.netTotal,
                                    semantic: MoneySemantic.neutral,
                                    hidden: hideBalances,
                                    showSign: true,
                                  ),
                                  const SizedBox(width: AppSpacing.space4),
                                  SizedBox.square(
                                    dimension: AppSpacing.space24,
                                    child: AnimatedRotation(
                                      turns: collapsed ? -0.25 : 0,
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      child: Icon(
                                        RemixIcons.arrow_down_s_line,
                                        size: AppSpacing.space18,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
            if (!collapsed) ...[
              const SizedBox(height: AppSpacing.space4),
              DragTarget<AccountView>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails:
                    (details) =>
                        onAccountDropped(details.data, accounts.length),
                builder:
                    (context, candidateData, child) => Column(
                      children: [
                        if (candidateData.isNotEmpty)
                          Container(
                            height: 3,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        for (var i = 0; i < accounts.length; i++)
                          DragTarget<AccountView>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails:
                                (details) => onAccountDropped(details.data, i),
                            builder:
                                (context, candidateData, child) => Column(
                                  children: [
                                    if (candidateData.isNotEmpty)
                                      Container(
                                        height: 3,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    _AccountRow(
                                      model: accounts[i],
                                      hideBalance: hideBalances,
                                    ),
                                  ],
                                ),
                          ),
                        if (accounts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.space8,
                              top: AppSpacing.space16,
                              bottom: AppSpacing.space16,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '长按并拖动账户到这里',
                                style: textStyles.listSupporting,
                              ),
                            ),
                          ),
                        if (accounts.isNotEmpty)
                          DragTarget<AccountView>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails:
                                (details) => onAccountDropped(
                                  details.data,
                                  accounts.length,
                                ),
                            builder:
                                (context, candidateData, child) =>
                                    candidateData.isEmpty
                                        ? const SizedBox(
                                          height: AppSpacing.space4,
                                        )
                                        : Container(
                                          height: 3,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                          ),
                      ],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.model, required this.hideBalance});

  final AccountView model;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic =
        model.accountType == AccountType.asset
            ? MoneySemantic.asset
            : MoneySemantic.liability;

    final row = AccountListRow(
      account: model,
      amountSemantic: semantic,
      hideBalance: hideBalance,
      onTap: () => context.push('/account/${model.id}'),
      trailing: SizedBox.square(
        dimension: AppSpacing.space24,
        child: Icon(
          RemixIcons.arrow_right_s_line,
          size: AppSpacing.space18,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    return LongPressDraggable<AccountView>(
      data: model,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 280, child: Opacity(opacity: 0.86, child: row)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: row),
      child: row,
    );
  }
}

class _ArchivedAccountsEntry extends StatelessWidget {
  const _ArchivedAccountsEntry({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.space48 + AppSpacing.space8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space16,
              vertical: AppSpacing.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('已归档账户', style: context.appTextStyles.formValue),
                ),
                Text('$count', style: context.appTextStyles.detailLabel),
                const SizedBox(width: AppSpacing.space8),
                Icon(
                  RemixIcons.arrow_right_s_line,
                  size: AppSpacing.space20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAccountGroupManagerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AccountGroupManagerSheet(),
  );
}

class _AccountGroupManagerSheet extends ConsumerWidget {
  const _AccountGroupManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(accountGroupsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: switch (groupsAsync) {
          AsyncData(value: final groups) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space20,
                  vertical: AppSpacing.space8,
                ),
                child: Row(
                  children: [
                    Text(
                      '管理账户分组',
                      style: context.appTextStyles.sectionTitleStrong,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _createGroup(context, ref),
                      icon: const Icon(RemixIcons.add_line),
                      label: const Text('新建分组'),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.space20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('长按并拖动可调整分组顺序'),
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: groups.length,
                  onReorder:
                      (oldIndex, newIndex) => _reorderGroups(
                        context,
                        ref,
                        groups,
                        oldIndex,
                        newIndex,
                      ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      key: ValueKey(group.id),
                      leading: ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Icon(RemixIcons.draggable),
                      ),
                      title: Text(group.name),
                      trailing: PopupMenuButton<_AccountGroupAction>(
                        onSelected:
                            (action) => _handleAction(
                              context,
                              ref,
                              group: group,
                              action: action,
                            ),
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: _AccountGroupAction.rename,
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(
                                value: _AccountGroupAction.delete,
                                child: Text('删除'),
                              ),
                            ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          AsyncError() => const Center(child: Text('分组加载失败，请稍后重试')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await _requestGroupName(context, title: '新建分组');
    if (name == null || !context.mounted) return;
    final outcome = await ref
        .read(accountOrganizationViewModelProvider.notifier)
        .createGroup(name);
    if (!context.mounted) return;
    _showGroupOutcome(context, outcome, successMessage: '分组已创建');
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref, {
    required AccountGroup group,
    required _AccountGroupAction action,
  }) async {
    switch (action) {
      case _AccountGroupAction.rename:
        final name = await _requestGroupName(
          context,
          title: '重命名分组',
          initialValue: group.name,
        );
        if (name == null || !context.mounted) return;
        final outcome = await ref
            .read(accountOrganizationViewModelProvider.notifier)
            .renameGroup(group.id, name);
        if (!context.mounted) return;
        _showGroupOutcome(context, outcome, successMessage: '分组已重命名');
      case _AccountGroupAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text('删除“${group.name}”？'),
                content: const Text('该分组中的账户会变为未分组，账户本身不会被删除。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
        );
        if (confirmed != true || !context.mounted) return;
        final outcome = await ref
            .read(accountOrganizationViewModelProvider.notifier)
            .deleteGroup(group.id);
        if (!context.mounted) return;
        _showGroupOutcome(context, outcome, successMessage: '分组已删除');
    }
  }

  Future<void> _reorderGroups(
    BuildContext context,
    WidgetRef ref,
    List<AccountGroup> groups,
    int oldIndex,
    int newIndex,
  ) async {
    final ordered = [...groups];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    final outcome = await ref
        .read(accountOrganizationViewModelProvider.notifier)
        .reorderGroups([for (final group in ordered) group.id]);
    if (!context.mounted) return;
    _showGroupOutcome(context, outcome, successMessage: '分组顺序已更新');
  }
}

enum _AccountGroupAction { rename, delete }

Future<String?> _requestGroupName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '请输入分组名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        ),
  );
  controller.dispose();
  return result;
}

void _showGroupOutcome(
  BuildContext context,
  UiActionOutcome<void> outcome, {
  required String successMessage,
}) {
  if (!context.mounted) return;
  final message = switch (outcome) {
    UiActionSuccess() => successMessage,
    UiActionFailure(:final error) => error.message,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyAccountsHint extends StatelessWidget {
  const _EmptyAccountsHint();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Row(
          children: [
            Icon(
              RemixIcons.wallet_3_line,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.space10),
            const Expanded(child: Text('还没有账户，点击右上角"+"新建')),
          ],
        ),
      ),
    );
  }
}

class _AccountsErrorView extends StatelessWidget {
  const _AccountsErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Text('账户加载失败：$error'),
      ),
    );
  }
}

String _formatMoney(int minor) {
  final money = Money(minorUnits: minor);
  return money.format();
}

String _formatSignedMoney(int minor) {
  final sign = minor >= 0 ? '+' : '-';
  return '$sign¥${Money(minorUnits: minor.abs()).format()}';
}

String _formatNetAssetComparison(PeriodChange change) {
  final delta = _formatSignedMoney(change.delta.minorUnits);
  final ratio = change.ratio;
  if (change.isFlat) {
    return '与上月持平';
  }
  if (change.isNewValue || ratio == null) {
    return '较上月 $delta';
  }
  final sign = ratio >= 0 ? '+' : '-';
  return '较上月 $delta ($sign${(ratio.abs() * 100).toStringAsFixed(2)}%)';
}
