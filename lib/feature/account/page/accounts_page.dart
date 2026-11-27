import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_bottom_navigation_layout_scope.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_header_select_button.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_tab_swipe_region.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/asset_view_presentation.dart';
import '../view_model/asset_page_view_model.dart';
import '../view_model/asset_section_collapse_view_model.dart';
import '../widget/account_creation_sheet.dart';
import '../widget/account_group_manager_sheet.dart';
import '../widget/asset_account_sections.dart';
import '../widget/asset_summary_card.dart';
import 'archived_accounts_page.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});
  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _hideBalances = false;
  @override
  Widget build(BuildContext context) {
    final page = ref.watch(assetPageStateProvider);
    final filter = ref.watch(assetPageViewModelProvider);
    final collapsed =
        ref.watch(assetSectionCollapseViewModelProvider).value ??
        const <String>{};
    final state = page.value;
    final content = state?.content;
    final viewName = content?.view.name ?? '资产视图';
    final sections = content?.layout.sections ?? [];
    final allCollapsed =
        content != null &&
        sections.isNotEmpty &&
        sections.every(
          (section) => collapsed.contains(
            assetSectionCollapseKey(content.view, section.id),
          ),
        );
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              showBackButton: false,
              singleRow: true,
              singleRowTitleAlignment: AppHeaderTitleAlignment.page,
              leading: AppHeaderSelectButton<String>(
                label: viewName,
                tooltip: '切换视图：$viewName',
                value: content?.view.id ?? '',
                onChanged: state == null ? null : _selectView,
                options: [
                  for (final view in state?.views ?? [])
                    AppSelectOption(
                      value: view.id,
                      label: view.name,
                      icon: RemixIcons.wallet_3_line,
                    ),
                ],
                actions: [
                  AppPopupMenuAction(
                    label: '新建',
                    icon: RemixIcons.add_line,
                    onPressed: state == null ? null : _createView,
                  ),
                  AppPopupMenuAction(
                    label: '管理',
                    icon: RemixIcons.settings_3_line,
                    onPressed: state == null ? null : _manageViews,
                  ),
                ],
              ),
              titleContent: AppSlidingSegmentedControl<AssetAccountFilter>(
                variant: AppSegmentedControlVariant.adaptiveHeader,
                selected: filter,
                onChanged: (value) => ref
                    .read(assetPageViewModelProvider.notifier)
                    .selectType(value),
                segments: [
                  for (final value in AssetAccountFilter.values)
                    AppSegment(value: value, label: value.label),
                ],
              ),
              actions: [
                if (sections.isNotEmpty)
                  AppHeaderIconButton(
                    icon: allCollapsed
                        ? RemixIcons.expand_up_down_line
                        : RemixIcons.contract_up_down_line,
                    tooltip: allCollapsed ? '展开全部分组' : '折叠全部分组',
                    onPressed: () {
                      final controller = ref.read(
                        assetSectionCollapseViewModelProvider.notifier,
                      );
                      final keys = sections.map(
                        (section) =>
                            assetSectionCollapseKey(content!.view, section.id),
                      );
                      if (allCollapsed) {
                        controller.expandSections(keys);
                      } else {
                        controller.collapseAll(keys);
                      }
                    },
                  ),
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新建账户',
                  onPressed: content == null ? null : _addAccount,
                ),
                AppPopupMenuButton(
                  tooltip: '更多操作',
                  icon: RemixIcons.more_2_fill,
                  items: [
                    AppPopupMenuAction(
                      label: '管理视图',
                      icon: RemixIcons.settings_3_line,
                      onPressed: _manageViews,
                    ),
                    AppPopupMenuAction(
                      label: '管理分组',
                      icon: RemixIcons.folder_settings_line,
                      onPressed: content == null
                          ? null
                          : () => showAccountGroupManagerSheet(
                              context,
                              viewId: content.view.id,
                            ),
                    ),
                    AppPopupMenuAction(
                      label: _hideBalances ? '显示余额' : '隐藏余额',
                      icon: _hideBalances
                          ? RemixIcons.eye_line
                          : RemixIcons.eye_off_line,
                      onPressed: () =>
                          setState(() => _hideBalances = !_hideBalances),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: AppTabSwipeRegion<AssetAccountFilter>(
                values: AssetAccountFilter.values,
                selected: filter,
                onChanged: (value) => ref
                    .read(assetPageViewModelProvider.notifier)
                    .selectType(value),
                child: page.when(
                  data: (state) => _content(state, collapsed, filter),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('资产视图加载失败，请稍后重试。'),
                        TextButton(
                          onPressed: () => ref
                              .read(assetPageViewModelProvider.notifier)
                              .retry(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    AssetPageState state,
    Set<String> collapsed,
    AssetAccountFilter filter,
  ) {
    final content = state.content;
    final view = content.view;
    final inset = AppBottomNavigationLayoutScope.of(context).contentInset;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space48 * 2 + inset,
      ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssetSummaryCard(
            statistics: content.statistics,
            hideBalances: _hideBalances,
          ),
          if (content.layout.isEmpty) ...[
            const SizedBox(height: AppSpacing.space24),
            AppSurface(
              child: AppEmptyState(
                layout: AppEmptyStateLayout.inline,
                icon: const Icon(RemixIcons.wallet_3_line),
                title: content.accounts.isEmpty
                    ? '还没有账户，点击右上角“＋”新建'
                    : filter == AssetAccountFilter.all
                    ? '当前视图暂无可展示账户'
                    : '当前视图没有${filter.label}账户',
              ),
            ),
          ],
        ],
      ),
      footer: content.archivedAccounts.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space20),
              child: _ArchivedAccountsEntry(
                count: content.archivedAccounts.length,
                onTap: () => context.push(
                  '/account/archived',
                  extra: ArchivedAccountsPageArguments(
                    initiallyHideBalances: _hideBalances,
                    viewId: view.id,
                    accountIds: view.accountIds.toSet(),
                    accountType: filter.accountType,
                  ),
                ),
              ),
            ),
      itemCount: content.layout.sections.length,
      onReorderItem: (oldIndex, newIndex) async => _showOutcome(
        await ref
            .read(assetPageViewModelProvider.notifier)
            .reorderGroups(view, content.layout.sections, oldIndex, newIndex),
      ),
      itemBuilder: (context, index) {
        final section = content.layout.sections[index];
        final key = assetSectionCollapseKey(view, section.id);
        return Padding(
          key: ValueKey(key),
          padding: EdgeInsets.only(
            top: index == 0 ? AppSpacing.space24 : AppSpacing.space20,
          ),
          child: AccountSectionCard(
            section: section,
            reorderIndex: index,
            collapsed: collapsed.contains(key),
            hideBalances: _hideBalances,
            onToggleCollapsed: () => ref
                .read(assetSectionCollapseViewModelProvider.notifier)
                .toggle(key),
            onAccountReorder: (oldIndex, newIndex) async => _showOutcome(
              await ref
                  .read(assetPageViewModelProvider.notifier)
                  .reorderAccounts(view, section, oldIndex, newIndex),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addAccount() async {
    final viewId = ref
        .read(assetPageStateProvider)
        .requireValue
        .content
        .view
        .id;
    final preset = await showAccountCreationSheet(context: context);
    if (preset != null && mounted) {
      final location = Uri.parse(preset.routeLocation);
      context.push(
        location
            .replace(
              queryParameters: {...location.queryParameters, 'view': viewId},
            )
            .toString(),
      );
    }
  }

  Future<void> _selectView(String id) async => _showOutcome(
    await ref.read(assetViewSelectionViewModelProvider.notifier).selectView(id),
  );

  Future<void> _createView() async {
    final saved = await context.push<String>('/assets/views/new');
    if (saved == null || !mounted) return;
    ref.invalidate(assetViewsProvider, asReload: true);
    ref
        .read(assetPageViewModelProvider.notifier)
        .selectType(AssetAccountFilter.all);
    _showOutcome(
      await ref
          .read(assetViewSelectionViewModelProvider.notifier)
          .selectView(saved),
    );
  }

  Future<void> _manageViews() async {
    final saved = await context.push<String>('/assets/views');
    if (saved == null || !mounted) return;
    ref.invalidate(assetViewsProvider, asReload: true);
    ref
        .read(assetPageViewModelProvider.notifier)
        .selectType(AssetAccountFilter.all);
    _showOutcome(
      await ref
          .read(assetViewSelectionViewModelProvider.notifier)
          .selectView(saved),
    );
  }

  void _showOutcome(UiActionOutcome<void> outcome) {
    if (outcome case UiActionFailure<void>(:final error) when mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
                  child: Text('已归档账户', style: context.appTextStyles.listTitle),
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
