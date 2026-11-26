import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/account_section_presentation.dart';
import '../view_model/account_view.dart';
import 'account_list_row.dart';

class AccountSectionCard extends StatelessWidget {
  const AccountSectionCard({
    required this.section,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.hideBalances = false,
    this.reorderIndex,
    this.onAccountReorder,
    super.key,
  });
  final AccountSectionPresentation section;
  final bool collapsed;
  final bool hideBalances;
  final VoidCallback onToggleCollapsed;
  final int? reorderIndex;
  final void Function(int, int)? onAccountReorder;

  @override
  Widget build(BuildContext context) {
    Widget header = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        onTap: onToggleCollapsed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.space48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.groupTitle,
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
                  duration: AppMotion.durationFast,
                  child: Icon(
                    RemixIcons.arrow_down_s_line,
                    size: AppSpacing.space18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reorderIndex != null && section.id != 'ungrouped') {
      header = ReorderableDelayedDragStartListener(
        index: reorderIndex!,
        child: header,
      );
    }
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space4,
        ),
        child: Column(
          children: [
            header,
            if (!collapsed) ...[
              const SizedBox(height: AppSpacing.space4),
              if (onAccountReorder == null)
                for (final account in section.accounts) _row(context, account)
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: section.accounts.length,
                  onReorderItem: onAccountReorder!,
                  itemBuilder: (context, index) =>
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(section.accounts[index].id),
                        index: index,
                        child: _row(context, section.accounts[index]),
                      ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AccountView account) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.space4),
    child: AccountListRow(
      account: account,
      amountSemantic: account.accountType == AccountType.asset
          ? MoneySemantic.asset
          : MoneySemantic.liability,
      hideBalance: hideBalances,
      onTap: () => context.push('/account/${account.id}'),
      trailing: SizedBox.square(
        dimension: AppSpacing.space24,
        child: Icon(
          RemixIcons.arrow_right_s_line,
          size: AppSpacing.space18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
