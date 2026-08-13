import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/account_section_presentation.dart';
import '../view_model/archived_accounts_view_model.dart';
import '../widget/account_list_row.dart';

class ArchivedAccountsPage extends ConsumerStatefulWidget {
  const ArchivedAccountsPage({super.key, this.initiallyHideBalances = false});

  final bool initiallyHideBalances;

  @override
  ConsumerState<ArchivedAccountsPage> createState() =>
      _ArchivedAccountsPageState();
}

class _ArchivedAccountsPageState extends ConsumerState<ArchivedAccountsPage> {
  late bool _hideBalances;
  final Set<String> _collapsedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _hideBalances = widget.initiallyHideBalances;
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(archivedAccountsViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '已归档账户',
              actions: [
                AppHeaderIconButton(
                  onPressed:
                      () => setState(() => _hideBalances = !_hideBalances),
                  icon:
                      _hideBalances
                          ? RemixIcons.eye_off_line
                          : RemixIcons.eye_line,
                  tooltip: _hideBalances ? '显示余额' : '隐藏余额',
                ),
              ],
            ),
            Expanded(
              child: switch (pageState) {
                ArchivedAccountsPageLoaded(:final sections) =>
                  _ArchivedAccountsContent(
                    sections: sections,
                    hideBalances: _hideBalances,
                    collapsedGroupIds: _collapsedGroupIds,
                    onToggleGroup:
                        (groupId) => setState(() {
                          _collapsedGroupIds.contains(groupId)
                              ? _collapsedGroupIds.remove(groupId)
                              : _collapsedGroupIds.add(groupId);
                        }),
                  ),
                ArchivedAccountsPageError(:final error) =>
                  _ArchivedAccountsError(message: error.message),
                ArchivedAccountsPageLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedAccountsContent extends StatelessWidget {
  const _ArchivedAccountsContent({
    required this.sections,
    required this.hideBalances,
    required this.collapsedGroupIds,
    required this.onToggleGroup,
  });

  final List<AccountSectionPresentation> sections;
  final bool hideBalances;
  final Set<String> collapsedGroupIds;
  final ValueChanged<String> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Center(child: Text('没有已归档账户'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space16,
        AppSpacing.space20,
        AppSpacing.space48,
      ),
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.space20),
          _ArchivedAccountGroup(
            section: sections[index],
            hideBalances: hideBalances,
            collapsed: collapsedGroupIds.contains(sections[index].id),
            onToggleCollapsed: () => onToggleGroup(sections[index].id),
          ),
        ],
      ],
    );
  }
}

class _ArchivedAccountGroup extends StatelessWidget {
  const _ArchivedAccountGroup({
    required this.section,
    required this.hideBalances,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final AccountSectionPresentation section;
  final bool hideBalances;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space4,
        ),
        child: Column(
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                onTap: onToggleCollapsed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.space48,
                  ),
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
                      Text(
                        '${section.accounts.length} 个账户',
                        style: context.appTextStyles.listSupporting,
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!collapsed) ...[
              const SizedBox(height: AppSpacing.space4),
              for (final account in section.accounts)
                AccountListRow(
                  account: account,
                  amountSemantic: MoneySemantic.neutral,
                  hideBalance: hideBalances,
                  onTap: () => context.push('/account/${account.id}'),
                  trailing: const Icon(
                    RemixIcons.arrow_right_s_line,
                    size: AppSpacing.space18,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchivedAccountsError extends StatelessWidget {
  const _ArchivedAccountsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Text(message),
      ),
    );
  }
}
