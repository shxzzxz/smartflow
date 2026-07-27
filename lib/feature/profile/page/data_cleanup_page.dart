import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/data_cleanup_presentation.dart';
import '../view_model/data_cleanup_view_model.dart';
import '../widget/cleanup_account_filter_sheet.dart';
import '../widget/cleanup_category_filter_sheet.dart';

class DataCleanupPage extends ConsumerWidget {
  const DataCleanupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(dataCleanupViewModelProvider);
    final preview = ref.watch(dataCleanupPreviewProvider);
    final deletableCount = preview.value?.deletableGroupCount ?? 0;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space16,
            AppSpacing.space20,
            AppSpacing.space24,
          ),
          children: [
            const AppPageHeader(
              title: '数据清理',
              subtitle: '按条件批量删除交易数据',
              showBackButton: true,
            ),
            const SizedBox(height: AppSpacing.space20),
            AppFormSection(
              title: '清理条件',
              description: '未设置的条件不做限制',
              children: [
                _TimeRangeRow(state: state),
                _CategoryRow(state: state),
                _AccountRow(state: state),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            AppFormSection(
              title: '清理预览',
              children: [_PreviewContent(preview: preview)],
            ),
            const SizedBox(height: AppSpacing.space24),
            const AppStatusBanner(
              tone: AppStatusBannerTone.danger,
              message: '清理会永久删除匹配的交易组及其账务记录，无法恢复。',
            ),
            const SizedBox(height: AppSpacing.space12),
            AppSubmitButton(
              label: '清理数据',
              tone: AppSubmitButtonTone.danger,
              loading: state.submitting,
              onPressed:
                  deletableCount > 0
                      ? () => _confirmCleanup(context, ref, preview.value!)
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCleanup(
    BuildContext context,
    WidgetRef ref,
    TransactionCleanupPreview preview,
  ) async {
    final danger =
        Theme.of(context).extension<AppThemeExtension>()?.danger ??
        Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清理数据'),
          content: Text(cleanupConfirmMessage(preview)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final outcome =
        await ref.read(dataCleanupViewModelProvider.notifier).cleanup();
    if (!context.mounted) return;
    final message = switch (outcome) {
      UiActionSuccess(:final value) => cleanupResultMessage(value),
      UiActionFailure(:final error) => error.message,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TimeRangeRow extends ConsumerWidget {
  const _TimeRangeRow({required this.state});

  final DataCleanupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return AppPlainFormRow(
      label: '时间范围',
      onTap: () => _pickRange(context, ref),
      child: Row(
        children: [
          Expanded(
            child: AppPlainValueText(
              text: cleanupTimeRangeLabel(
                state.occurredFrom,
                state.occurredUntilExclusive,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (state.hasTimeRange)
            IconButton(
              onPressed:
                  () =>
                      ref
                          .read(dataCleanupViewModelProvider.notifier)
                          .clearTimeRange(),
              icon: const Icon(RemixIcons.close_circle_line),
              iconSize: AppSpacing.space18,
              color: colors.onSurfaceVariant,
              tooltip: '恢复全部时间',
            )
          else
            Icon(
              RemixIcons.arrow_right_s_line,
              color: colors.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = ref.read(currentDateTimeProvider);
    final today = DateTime(now.year, now.month, now.day);
    final initialRange =
        state.hasTimeRange
            ? DateTimeRange(
              start: state.occurredFrom!,
              end: state.occurredUntilExclusive!.subtract(
                const Duration(days: 1),
              ),
            )
            : DateTimeRange(
              start: DateTime(today.year, today.month, 1),
              end: today,
            );
    final range = await showAppDateRangePicker(
      context: context,
      initialRange: initialRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (range == null || !context.mounted) return;
    ref
        .read(dataCleanupViewModelProvider.notifier)
        .setTimeRange(from: range.start, untilInclusive: range.end);
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.state});

  final DataCleanupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SelectValueRow(
      label: '分类',
      value: cleanupSelectionLabel(state.categoryIds.length, '全部分类'),
      onTap: () async {
        final notifier = ref.read(dataCleanupViewModelProvider.notifier);
        final expenseTree = await notifier.categoryTreeOptions(
          AccountType.expense,
        );
        final incomeTree = await notifier.categoryTreeOptions(
          AccountType.income,
        );
        if (!context.mounted) return;
        final selected = await showCleanupCategoryFilterSheet(
          context: context,
          expenseTree: expenseTree,
          incomeTree: incomeTree,
          selectedIds: state.categoryIds,
        );
        if (selected == null || !context.mounted) return;
        ref
            .read(dataCleanupViewModelProvider.notifier)
            .setCategoryIds(selected);
      },
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.state});

  final DataCleanupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SelectValueRow(
      label: '账户',
      value: cleanupSelectionLabel(state.accountIds.length, '全部账户'),
      onTap: () async {
        final accounts =
            await ref
                .read(dataCleanupViewModelProvider.notifier)
                .accountOptions();
        if (!context.mounted) return;
        final selected = await showCleanupAccountFilterSheet(
          context: context,
          accounts: accounts,
          selectedIds: state.accountIds,
        );
        if (selected == null || !context.mounted) return;
        ref.read(dataCleanupViewModelProvider.notifier).setAccountIds(selected);
      },
    );
  }
}

class _SelectValueRow extends StatelessWidget {
  const _SelectValueRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppPlainFormRow(
      label: label,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: AppPlainValueText(text: value, textAlign: TextAlign.right),
          ),
          Icon(RemixIcons.arrow_right_s_line, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.preview});

  final AsyncValue<TransactionCleanupPreview> preview;

  @override
  Widget build(BuildContext context) {
    switch (preview) {
      case AsyncData(:final value):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPlainValueRow(
              label: '可清理交易组',
              value: '${value.deletableGroupCount} 组',
            ),
            if (value.ownedGroupCount > 0) ...[
              const SizedBox(height: AppSpacing.space8),
              AppStatusBanner(
                tone: AppStatusBannerTone.info,
                message:
                    '另有 ${value.ownedGroupCount} 组信贷关联交易不会被清理，'
                    '请在信贷模块中处理。',
              ),
            ],
          ],
        );
      case AsyncError():
        return const AppStatusBanner(
          tone: AppStatusBannerTone.warning,
          message: '预览加载失败，请返回后重试。',
        );
      default:
        return const AppPlainValueRow(label: '可清理交易组', value: '统计中…');
    }
  }
}
