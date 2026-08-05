import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/token/typography.dart';
import '../data/manual_catalog.dart';
import '../model/manual_article.dart';
import 'manual_markdown.dart';

/// 打开「文章目录」底部面板：按分类列出全部文章，点击跳转。
Future<void> showManualArticleDirectorySheet({
  required BuildContext context,
  required String currentSlug,
  required ValueChanged<String> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => _ManualArticleDirectorySheet(
          currentSlug: currentSlug,
          onSelect: (slug) {
            Navigator.of(sheetContext).pop();
            onSelect(slug);
          },
        ),
  );
}

/// 打开「本页目录」底部面板：列出当前文章的章节，点击滚动定位。
Future<void> showManualArticleTocSheet({
  required BuildContext context,
  required List<ManualHeading> headings,
  required ValueChanged<String> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => _ManualArticleTocSheet(
          headings: headings,
          onSelect: (key) {
            Navigator.of(sheetContext).pop();
            onSelect(key);
          },
        ),
  );
}

class _ManualArticleDirectorySheet extends StatelessWidget {
  const _ManualArticleDirectorySheet({
    required this.currentSlug,
    required this.onSelect,
  });

  final String currentSlug;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final groups = <String, List<ManualArticle>>{};
    for (final category in manualCategories.skip(1)) {
      final articles =
          manualArticles
              .where((article) => article.category == category)
              .toList();
      if (articles.isNotEmpty) {
        groups[category] = articles;
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space20,
              AppSpacing.space4,
              AppSpacing.space20,
              AppSpacing.space8,
            ),
            child: Text('文章目录', style: styles.pageTitle),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.space16),
              children: [
                for (final group in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space20,
                      AppSpacing.space12,
                      AppSpacing.space20,
                      AppSpacing.space4,
                    ),
                    child: Row(
                      children: [
                        Text(group.key, style: styles.groupTitle),
                        const SizedBox(width: AppSpacing.space8),
                        Text(
                          '${group.value.length} 篇',
                          style: styles.listSupporting,
                        ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < group.value.length; index++) ...[
                    _DirectoryRow(
                      article: group.value[index],
                      selected: group.value[index].slug == currentSlug,
                      onTap: () => onSelect(group.value[index].slug),
                    ),
                    if (index < group.value.length - 1)
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.article,
    required this.selected,
    required this.onTap,
  });

  final ManualArticle article;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space20,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                article.title,
                style: styles.formValue.copyWith(
                  color: selected ? colors.primary : null,
                  fontWeight: AppTypography.titleWeight,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            if (selected)
              Icon(RemixIcons.check_line, color: colors.primary, size: 20)
            else
              Icon(
                RemixIcons.arrow_right_s_line,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualArticleTocSheet extends StatelessWidget {
  const _ManualArticleTocSheet({
    required this.headings,
    required this.onSelect,
  });

  final List<ManualHeading> headings;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space20,
              AppSpacing.space4,
              AppSpacing.space20,
              AppSpacing.space8,
            ),
            child: Row(
              children: [
                Text('本页目录', style: styles.pageTitle),
                const SizedBox(width: AppSpacing.space8),
                Text('${headings.length} 节', style: styles.listSupporting),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.space16),
              children: [
                for (final heading in headings)
                  _TocSheetItem(
                    heading: heading,
                    onTap: () => onSelect(heading.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TocSheetItem extends StatelessWidget {
  const _TocSheetItem({required this.heading, required this.onTap});

  final ManualHeading heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final isSub = heading.level == 3;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space20 + (isSub ? AppSpacing.space16 : 0),
          AppSpacing.space10,
          AppSpacing.space20,
          AppSpacing.space10,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.space6,
              height: AppSpacing.space6,
              decoration: BoxDecoration(
                color:
                    isSub
                        ? colors.onSurfaceVariant.withValues(alpha: 0.6)
                        : colors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Expanded(
              child: Text(
                heading.text,
                style:
                    isSub
                        ? styles.listSupporting
                        : styles.formValue.copyWith(
                          fontWeight: AppTypography.emphasisWeight,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
