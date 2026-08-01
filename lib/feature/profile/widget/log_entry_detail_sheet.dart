import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../../core/logging/app_log_reader.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../presentation/log_viewer_presentation.dart';

Future<void> showLogEntryDetailSheet({
  required BuildContext context,
  required AppLogEntry entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _LogEntryDetailSheet(entry: entry),
  );
}

class _LogEntryDetailSheet extends StatelessWidget {
  const _LogEntryDetailSheet({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            0,
            AppSpacing.space20,
            AppSpacing.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LogLevelBadge(level: entry.level),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      logEntryDetailTimeLabel(entry.time),
                      style: textStyles.listSupporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded),
                    iconSize: 20,
                    tooltip: '复制日志',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                entry.loggerName,
                style: textStyles.listSupporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        entry.message,
                        style: textStyles.detailValue,
                      ),
                      if (entry.error != null) ...[
                        const SizedBox(height: AppSpacing.space12),
                        _DetailSection(title: '错误', content: entry.error!),
                      ],
                      if (entry.stackTrace != null) ...[
                        const SizedBox(height: AppSpacing.space12),
                        _DetailSection(
                          title: '调用栈',
                          content: entry.stackTrace!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: logEntryCopyText(entry)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日志已复制')));
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textStyles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.space12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          ),
          child: SelectableText(
            content,
            style: textStyles.listSupporting.copyWith(
              fontFamily: 'monospace',
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class LogLevelBadge extends StatelessWidget {
  const LogLevelBadge({required this.level, super.key});

  final Level level;

  @override
  Widget build(BuildContext context) {
    final color = logLevelColor(context, level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: Text(
        logLevelLabel(level),
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
      ),
    );
  }
}

Color logLevelColor(BuildContext context, Level level) {
  final theme = Theme.of(context);
  final extension = theme.extension<AppThemeExtension>();
  if (level >= Level.SEVERE) {
    return extension?.danger ?? theme.colorScheme.error;
  }
  if (level >= Level.WARNING) {
    return extension?.warning ?? theme.colorScheme.tertiary;
  }
  if (level >= Level.INFO) {
    return extension?.info ?? theme.colorScheme.primary;
  }
  return theme.colorScheme.onSurfaceVariant;
}
