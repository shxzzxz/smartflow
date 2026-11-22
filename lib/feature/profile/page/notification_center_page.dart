import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/notification/notification_message.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/notification_center_view_model.dart';

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(notificationCenterViewModelProvider.notifier).refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationCenterViewModelProvider);
    final notifier = ref.read(notificationCenterViewModelProvider.notifier);
    final unreadCount = state.value?.unreadCount ?? 0;
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '通知中心',
              subtitle: unreadCount > 0 ? '$unreadCount 条未读' : null,
              actions: [
                AppHeaderTextButton(
                  label: '全部已读',
                  onPressed: unreadCount == 0
                      ? null
                      : () => _showOutcome(context, notifier.markAllRead()),
                ),
              ],
            ),
            Expanded(
              child: state.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: AppEmptyState(
                    title: '通知加载失败',
                    message: '请稍后重试。',
                    action: TextButton(
                      onPressed: () =>
                          _showOutcome(context, notifier.refresh()),
                      child: const Text('重试'),
                    ),
                  ),
                ),
                data: (value) {
                  if (value.messages.isEmpty) {
                    return const Center(
                      child: AppEmptyState(
                        title: '暂无通知',
                        icon: Icon(RemixIcons.notification_3_line),
                        message: '提醒会在指定时间出现在这里。',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space24,
                    ),
                    itemCount: value.messages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.space12),
                    itemBuilder: (_, index) {
                      final message = value.messages[index];
                      return AppListSection(
                        key: ValueKey(message.identity),
                        children: [
                          _NotificationRow(
                            message: message,
                            onTap: () async {
                              final outcome = await notifier.markRead(message);
                              if (!context.mounted) return;
                              if (outcome is UiActionSuccess<void>) {
                                await context.push(message.plan.route);
                              } else if (outcome case UiActionFailure<void>(
                                :final error,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOutcome(
    BuildContext context,
    Future<UiActionOutcome<void>> action,
  ) async {
    final outcome = await action;
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.message, required this.onTap});

  final NotificationMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Semantics(
      button: true,
      label: message.isRead ? '已读' : '未读',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Badge(
                isLabelVisible: !message.isRead,
                child: Icon(
                  RemixIcons.notification_3_line,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.plan.title, style: styles.listTitle),
                    const SizedBox(height: AppSpacing.space8),
                    Text(message.plan.body, style: styles.formSupporting),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      DateFormat(
                        'yyyy年M月d日 HH:mm',
                      ).format(message.plan.scheduledAt.toLocal()),
                      style: styles.listSupporting,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
