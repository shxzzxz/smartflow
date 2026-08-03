import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../view_model/account_view.dart';
import '../view_model/account_views_provider.dart';
import '../view_model/asset_section_collapse_view_model.dart';

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
    final groupsAsync = ref.watch(accountGroupsProvider);
    final balanceSheetAsync = ref.watch(balanceSheetComparisonProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: switch ((accountsAsync, groupsAsync, balanceSheetAsync)) {
          (
            AsyncData(value: final accounts),
            AsyncData(value: final groups),
            AsyncData(value: final balanceSheet),
          ) =>
            _AccountsContent(
              accounts: accounts,
              groups: groups,
              balanceSheet: balanceSheet,
              hideBalances: _hideBalances,
              onToggleHide:
                  () => setState(() => _hideBalances = !_hideBalances),
            ),
          (AsyncError(:final error), _, _) ||
          (_, AsyncError(:final error), _) ||
          (_, _, AsyncError(:final error)) => _AccountsErrorView(error: error),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _AccountsContent extends ConsumerWidget {
  const _AccountsContent({
    required this.accounts,
    required this.groups,
    required this.balanceSheet,
    required this.hideBalances,
    required this.onToggleHide,
  });

  final List<AccountView> accounts;
  final List<AccountGroup> groups;
  final BalanceSheetComparison balanceSheet;
  final bool hideBalances;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = _buildSections(accounts, groups);
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
        ),
        const SizedBox(height: AppSpacing.space18),
        _NetAssetCard(comparison: balanceSheet, hideBalances: hideBalances),
        if (sections.isEmpty) ...[
          const SizedBox(height: AppSpacing.space24),
          const _EmptyAccountsHint(),
        ],
        for (final section in sections) ...[
          const SizedBox(height: AppSpacing.space24),
          _AccountSection(
            section: section,
            hideBalances: hideBalances,
            collapsed: collapsedKeys.contains(section.id),
            onToggleCollapsed:
                () => ref
                    .read(assetSectionCollapseViewModelProvider.notifier)
                    .toggle(section.id),
            onAccountDropped: (account) {
              final orderedIds = [
                for (final item in section.accounts)
                  if (item.id != account.id) item.id,
                account.id,
              ];
              ref
                  .read(accountGroupAppServiceProvider)
                  .moveAccountToGroup(
                    MoveAccountToGroupCommand(
                      accountId: account.id,
                      groupId: section.id == 'ungrouped' ? null : section.id,
                      orderedAccountIds: orderedIds,
                    ),
                  );
            },
          ),
        ],
      ],
    );
  }
}

class _SectionSpec {
  const _SectionSpec({
    required this.id,
    required this.title,
    required this.accounts,
  });

  final String id;
  final String title;
  final List<AccountView> accounts;

  Money totalFor(AccountType type) {
    return Money(
      minorUnits: accounts.fold(0, (sum, account) {
        return sum +
            (account.accountType == type ? account.balance.minorUnits : 0);
      }),
    );
  }
}

List<_SectionSpec> _buildSections(
  List<AccountView> accounts,
  List<AccountGroup> groups,
) {
  final sections = <_SectionSpec>[
    for (final group in groups)
      _SectionSpec(
        id: group.id,
        title: group.name,
        accounts: [
          for (final account in accounts)
            if (account.groupId == group.id) account,
        ],
      ),
  ];
  final ungrouped = [
    for (final account in accounts)
      if (account.groupId == null) account,
  ];
  if (ungrouped.isNotEmpty) {
    sections.add(
      _SectionSpec(id: 'ungrouped', title: '未分组', accounts: ungrouped),
    );
  }
  return sections;
}

class _AssetsHeader extends StatelessWidget {
  const _AssetsHeader({
    required this.hideBalances,
    required this.onToggleHide,
    required this.allCollapsed,
    required this.onToggleCollapseAll,
  });

  final bool hideBalances;
  final VoidCallback onToggleHide;

  /// null 表示没有可折叠的分组，不显示折叠按钮。
  final bool? allCollapsed;
  final VoidCallback onToggleCollapseAll;

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
        IconButton(
          onPressed: onToggleHide,
          icon: Icon(
            hideBalances ? RemixIcons.eye_off_line : RemixIcons.eye_line,
            color: colors.onSurfaceVariant,
          ),
          tooltip: hideBalances ? '显示余额' : '隐藏余额',
        ),
      ],
    );
  }
}

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
  });

  final _SectionSpec section;
  final bool hideBalances;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<AccountView> onAccountDropped;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final accounts = section.accounts;
    return Column(
      children: [
        InkWell(
          onTap: onToggleCollapsed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Row(
              children: [
                Text(section.title, style: textStyles.groupTitle),
                const Spacer(),
                _SectionTotal(
                  label: '资产',
                  money: section.totalFor(AccountType.asset),
                  semantic: MoneySemantic.asset,
                  hidden: hideBalances,
                ),
                const SizedBox(width: AppSpacing.space10),
                _SectionTotal(
                  label: '负债',
                  money: section.totalFor(AccountType.liability),
                  semantic: MoneySemantic.liability,
                  hidden: hideBalances,
                ),
                const SizedBox(width: AppSpacing.space6),
                AnimatedRotation(
                  turns: collapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    RemixIcons.arrow_down_s_line,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          const SizedBox(height: AppSpacing.space12),
          DragTarget<AccountView>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => onAccountDropped(details.data),
            builder:
                (context, candidateData, child) => AppSurface(
                  child: Column(
                    children: [
                      if (candidateData.isNotEmpty)
                        Container(
                          height: 3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      for (var i = 0; i < accounts.length; i++) ...[
                        _AccountRow(
                          model: accounts[i],
                          hideBalance: hideBalances,
                        ),
                        if (i < accounts.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.space48 + AppSpacing.space24,
                              right: AppSpacing.space16,
                            ),
                            child: Divider(height: 1),
                          ),
                      ],
                      if (accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.space16),
                          child: Text('长按并拖动账户到这里'),
                        ),
                    ],
                  ),
                ),
          ),
        ],
      ],
    );
  }
}

class _SectionTotal extends StatelessWidget {
  const _SectionTotal({
    required this.label,
    required this.money,
    required this.semantic,
    required this.hidden,
  });

  final String label;
  final Money money;
  final MoneySemantic semantic;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: context.appTextStyles.detailLabel.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        hidden
            ? const _HiddenMoneyText()
            : MoneyText(
              money: money,
              semantic: semantic,
              style: context.appTextStyles.amountList,
            ),
      ],
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
    final textStyles = context.appTextStyles;
    final semantic =
        model.accountType == AccountType.asset
            ? MoneySemantic.asset
            : MoneySemantic.liability;

    final row = InkWell(
      onTap: () => context.push('/account/${model.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            BusinessIconBubble(
              size: AppSpacing.space32,
              child: BusinessIcon(
                iconKey: model.iconKey,
                size: AppSpacing.space28,
                usage: BusinessIconUsage.account,
              ),
            ),
            const SizedBox(width: AppSpacing.space14),
            Expanded(
              child: Text(
                model.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.formValue,
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                hideBalance
                    ? const _HiddenMoneyText()
                    : MoneyText(
                      money: model.balance,
                      semantic: semantic,
                      style: textStyles.amountList,
                    ),
                if (model.isLiability &&
                    (model.billingDay != null ||
                        model.repaymentDay != null)) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    _liabilityDateText(model),
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
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

class _HiddenMoneyText extends StatelessWidget {
  const _HiddenMoneyText();

  @override
  Widget build(BuildContext context) {
    return Text('¥ ****', style: context.appTextStyles.amountList);
  }
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

String _liabilityDateText(AccountView account) {
  final parts = <String>[];
  if (account.billingDay != null) {
    parts.add('出账日 ${account.billingDay}');
  }
  if (account.repaymentDay != null) {
    parts.add('还款日 ${account.repaymentDay}');
  }
  return parts.join('   ');
}
