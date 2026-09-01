import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/data_management/backup/backup_archive.dart';
import '../../../application/data_management/backup/backup_models.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/backup_view_model.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupViewModelProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '数据备份', subtitle: '导出或恢复完整账本快照'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  AppSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '完整快照',
                            style: context.appTextStyles.sectionTitleStrong,
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          Text(
                            '备份包含账务、信贷和导入数据，使用原始 ID 与时间保存。移动端将备份保存为 ZIP 文件。',
                            style: context.appTextStyles.listSupporting
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.space16),
                          AppSubmitButton(
                            label: '导出备份',
                            loading: state.busy,
                            onPressed: state.busy
                                ? null
                                : () => ref
                                      .read(backupViewModelProvider.notifier)
                                      .export(),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          OutlinedButton.icon(
                            onPressed: state.busy
                                ? null
                                : () => _restore(context, ref),
                            icon: const Icon(RemixIcons.download_2_line),
                            label: const Text('选择备份并恢复'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: AppSpacing.space16),
                    AppStatusBanner(
                      message: state.message!,
                      tone: AppStatusBannerTone.success,
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.space16),
                    AppStatusBanner(
                      message: state.error!.message,
                      tone: AppStatusBannerTone.danger,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space16),
                  const AppStatusBanner(
                    tone: AppStatusBannerTone.warning,
                    message: '恢复会整体替换当前数据。恢复前请先导出一份安全快照。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(backupViewModelProvider.notifier);
    final picked = await viewModel.pickForRestore();
    if (!context.mounted || picked is! UiActionSuccess<BackupSelection?>) {
      return;
    }
    final selection = picked.value;
    if (selection == null) return;
    try {
      final compared = await viewModel.compare(selection);
      if (!context.mounted || compared is! UiActionSuccess<BackupDiff>) {
        return;
      }
      final diff = compared.value;
      if (diff.isNoop) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('数据完全一致，无需恢复。')));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认恢复'),
          content: Text(diff.summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('整体替换'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await viewModel.restore(selection);
      }
    } finally {
      await selection.dispose();
    }
  }
}
