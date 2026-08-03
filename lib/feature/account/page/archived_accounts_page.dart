import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/account_organization_view_model.dart';
import '../view_model/account_view.dart';
import '../view_model/account_views_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _hideBalances = widget.initiallyHideBalances;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(archivedAccountViewsProvider);
    final groupsAsync = ref.watch(accountGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('已归档账户'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _hideBalances = !_hideBalances),
            icon: Icon(
              _hideBalances ? RemixIcons.eye_off_line : RemixIcons.eye_line,
            ),
            tooltip: _hideBalances ? '显示余额' : '隐藏余额',
          ),
        ],
      ),
      body: switch ((accountsAsync, groupsAsync)) {
        (AsyncData(value: final accounts), AsyncData(value: final groups)) =>
          _ArchivedAccountsContent(
            sections: _buildArchivedSections(accounts, groups),
            hideBalances: _hideBalances,
          ),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => _ArchivedAccountsError(error: error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ArchivedSectionSpec {
  const _ArchivedSectionSpec({required this.title, required this.accounts});

  final String title;
  final List<AccountView> accounts;
}

List<_ArchivedSectionSpec> _buildArchivedSections(
  List<AccountView> accounts,
  List<AccountGroup> groups,
) {
  final sections = <_ArchivedSectionSpec>[];
  final knownGroupIds = {for (final group in groups) group.id};
  for (final group in groups) {
    final groupedAccounts = [
      for (final account in accounts)
        if (account.groupId == group.id) account,
    ];
    if (groupedAccounts.isNotEmpty) {
      sections.add(
        _ArchivedSectionSpec(title: group.name, accounts: groupedAccounts),
      );
    }
  }
  final ungroupedAccounts = [
    for (final account in accounts)
      if (account.groupId == null || !knownGroupIds.contains(account.groupId))
        account,
  ];
  if (ungroupedAccounts.isNotEmpty) {
    sections.add(
      _ArchivedSectionSpec(title: '未分组', accounts: ungroupedAccounts),
    );
  }
  return sections;
}

class _ArchivedAccountsContent extends ConsumerWidget {
  const _ArchivedAccountsContent({
    required this.sections,
    required this.hideBalances,
  });

  final List<_ArchivedSectionSpec> sections;
  final bool hideBalances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onRestore: (account) => _restoreAccount(context, ref, account.id),
          ),
        ],
      ],
    );
  }

  Future<void> _restoreAccount(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    final outcome = await ref
        .read(accountOrganizationViewModelProvider.notifier)
        .restoreAccount(accountId);
    if (!context.mounted) return;
    final message = switch (outcome) {
      UiActionSuccess<void>() => '账户已恢复',
      UiActionFailure<void>(:final error) => error.message,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ArchivedAccountGroup extends StatelessWidget {
  const _ArchivedAccountGroup({
    required this.section,
    required this.hideBalances,
    required this.onRestore,
  });

  final _ArchivedSectionSpec section;
  final bool hideBalances;
  final ValueChanged<AccountView> onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space4,
        ),
        child: Column(
          children: [
            ConstrainedBox(
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
                  Text(
                    '${section.accounts.length} 个账户',
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            for (final account in section.accounts)
              AccountListRow(
                account: account,
                amountSemantic: MoneySemantic.neutral,
                hideBalance: hideBalances,
                onTap: () => context.push('/account/${account.id}'),
                trailing: IconButton(
                  onPressed: () => onRestore(account),
                  icon: Icon(
                    RemixIcons.inbox_unarchive_line,
                    color: colors.onSurfaceVariant,
                  ),
                  tooltip: '恢复账户',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedAccountsError extends StatelessWidget {
  const _ArchivedAccountsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Text('已归档账户加载失败：$error'),
      ),
    );
  }
}
