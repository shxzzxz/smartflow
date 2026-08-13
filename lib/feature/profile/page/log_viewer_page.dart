import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/logging/app_log_reader.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/log_viewer_presentation.dart';
import '../view_model/log_viewer_view_model.dart';
import '../widget/log_entry_detail_sheet.dart';
import '../widget/log_retention_settings_sheet.dart';

class LogViewerPage extends ConsumerWidget {
  const LogViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(logViewerViewModelProvider);
    final entries = ref.watch(logEntriesProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space20,
                AppSpacing.space16,
                AppSpacing.space20,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: '日志',
                    actions: [
                      AppHeaderIconButton(
                        icon: RemixIcons.refresh_line,
                        tooltip: '刷新',
                        onPressed:
                            () =>
                                ref
                                    .read(logViewerViewModelProvider.notifier)
                                    .refresh(),
                      ),
                      AppHeaderIconButton(
                        icon: RemixIcons.settings_3_line,
                        tooltip: '清理设置',
                        onPressed:
                            () =>
                                showLogRetentionSettingsSheet(context: context),
                      ),
                      AppHeaderIconButton(
                        icon: RemixIcons.delete_bin_6_line,
                        tooltip: '清空日志',
                        onPressed: () => _confirmClear(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _SearchField(
                    onChanged:
                        ref.read(logViewerViewModelProvider.notifier).setQuery,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppSegmentedControl<LogLevelFilter>(
                      segments: const [
                        AppSegment(value: LogLevelFilter.all, label: '全部'),
                        AppSegment(value: LogLevelFilter.fine, label: '调试'),
                        AppSegment(value: LogLevelFilter.info, label: '信息'),
                        AppSegment(value: LogLevelFilter.warning, label: '警告'),
                        AppSegment(value: LogLevelFilter.severe, label: '错误'),
                      ],
                      selected: state.levelFilter,
                      size: AppSegmentedControlSize.small,
                      onChanged:
                          ref
                              .read(logViewerViewModelProvider.notifier)
                              .setLevelFilter,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                ],
              ),
            ),
            Expanded(child: _LogEntryList(entries: entries, state: state)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空日志'),
          content: const Text('将删除全部本地日志文件，无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final outcome =
        await ref.read(logViewerViewModelProvider.notifier).clearLogs();
    if (!context.mounted) return;
    final message = switch (outcome) {
      UiActionSuccess() => '日志已清空',
      UiActionFailure(:final error) => error.message,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.appTextStyles.inputText,
      decoration: InputDecoration(
        hintText: '搜索消息、来源或错误内容',
        hintStyle: context.appTextStyles.inputText.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          RemixIcons.search_line,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(
              alpha: AppComponentTokens.mutedOutlineOpacity,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
    );
  }
}

class _LogEntryList extends StatelessWidget {
  const _LogEntryList({required this.entries, required this.state});

  final AsyncValue<List<AppLogEntry>> entries;
  final LogViewerState state;

  @override
  Widget build(BuildContext context) {
    switch (entries) {
      case AsyncData(:final value):
        final filtered = filterLogEntries(
          value,
          levelFilter: state.levelFilter,
          query: state.query,
        );
        if (filtered.isEmpty) {
          return _EmptyPlaceholder(message: value.isEmpty ? '暂无日志' : '没有匹配的日志');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            0,
            AppSpacing.space20,
            AppSpacing.space24,
          ),
          itemCount: filtered.length,
          separatorBuilder:
              (context, index) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: AppComponentTokens.mutedOutlineOpacity,
                ),
              ),
          itemBuilder:
              (context, index) => _LogEntryTile(entry: filtered[index]),
        );
      case AsyncError():
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: Align(
            alignment: Alignment.topCenter,
            child: AppStatusBanner(
              tone: AppStatusBannerTone.warning,
              message: '日志读取失败，请刷新重试。',
            ),
          ),
        );
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: () => showLogEntryDetailSheet(context: context, entry: entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LogLevelBadge(level: entry.level),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    '${logEntryTimeLabel(entry.time)} · ${entry.loggerName}',
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              entry.message,
              style: textStyles.listTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.error != null) ...[
              const SizedBox(height: AppSpacing.space2),
              Text(
                entry.error!,
                style: textStyles.listSupporting.copyWith(
                  color: logLevelColor(context, entry.level),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            RemixIcons.file_list_3_line,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(message, style: context.appTextStyles.pageSubtitle),
        ],
      ),
    );
  }
}
