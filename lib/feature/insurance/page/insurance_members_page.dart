import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/insurance_members_view_model.dart';
import '../widget/member/insurance_member_tile.dart';

class InsuranceMembersPage extends ConsumerWidget {
  const InsuranceMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(insuranceMembersViewModelProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '成员管理',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.user_add_line,
                  tooltip: '新增成员',
                  onPressed: () => context.push('/insurance/members/new'),
                ),
              ],
            ),
            Expanded(
              child: members.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(insuranceMembersViewModelProvider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? AppEmptyState(
                        title: '还没有成员',
                        message: '先添加家庭成员，再记录商业保险和社保信息。',
                        icon: const Icon(RemixIcons.user_heart_line),
                        action: FilledButton.icon(
                          onPressed: () =>
                              context.push('/insurance/members/new'),
                          icon: const Icon(RemixIcons.add_line),
                          label: const Text('添加成员'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space16,
                          AppSpacing.space8,
                          AppSpacing.space16,
                          AppSpacing.space32,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.space12),
                        itemBuilder: (context, index) {
                          final member = items[index];
                          return InsuranceMemberTile(
                            member: member,
                            onTap: () => context.push(
                              '/insurance/members/'
                              '${member.insuredPersonId}',
                            ),
                            trailing: AppPopupMenuButton(
                              tooltip: '${member.name}的操作',
                              icon: RemixIcons.more_2_line,
                              items: [
                                AppPopupMenuAction(
                                  label: '编辑成员',
                                  icon: RemixIcons.edit_line,
                                  onPressed: () => context.push(
                                    '/insurance/members/'
                                    '${member.insuredPersonId}/edit',
                                  ),
                                ),
                                AppPopupMenuAction(
                                  label: '删除成员',
                                  icon: RemixIcons.delete_bin_line,
                                  onPressed: () => _deleteMember(
                                    context,
                                    ref,
                                    member.insuredPersonId,
                                    member.name,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMember(
    BuildContext context,
    WidgetRef ref,
    String insuredPersonId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除成员'),
        content: Text('确定删除“$name”吗？仅未被任何保险记录引用时才能删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final outcome = await ref
        .read(insuranceMembersViewModelProvider.notifier)
        .delete(insuredPersonId);
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
