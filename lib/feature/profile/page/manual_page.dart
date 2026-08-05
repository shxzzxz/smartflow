import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../data/manual_catalog.dart';
import '../model/manual_article.dart';
import '../widget/manual_widgets.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  String _query = '';

  List<MapEntry<String, List<ManualArticle>>> get _groups {
    final groups = <String, List<ManualArticle>>{};
    for (final category in manualCategories.skip(1)) {
      final inCategory =
          manualArticles
              .where(
                (article) =>
                    article.category == category && article.matches(_query),
              )
              .toList();
      if (inCategory.isNotEmpty) {
        groups[category] = inCategory;
      }
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    final groups = _groups;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('使用手册')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          AppSpacing.space8,
          AppSpacing.space20,
          AppSpacing.space32,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Text(
              '从记录第一笔账开始，逐步理解账户、交易和信贷功能。',
              style: styles.pageSubtitle,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          SearchBar(
            leading: const Icon(RemixIcons.search_line),
            hintText: '搜索手册',
            onChanged: (value) => setState(() => _query = value),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: '清除搜索',
                  icon: const Icon(RemixIcons.close_line),
                  onPressed: () => setState(() => _query = ''),
                ),
            ],
          ),
          if (groups.isEmpty) ...[
            const SizedBox(height: AppSpacing.space24),
            const _ManualEmptyState(),
          ] else
            for (final group in groups) ...[
              const SizedBox(height: AppSpacing.space24),
              _ManualSection(category: group.key, articles: group.value),
            ],
        ],
      ),
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection({required this.category, required this.articles});

  final String category;
  final List<ManualArticle> articles;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Row(
            children: [
              Text(category, style: styles.groupTitle),
              const SizedBox(width: AppSpacing.space8),
              Text('${articles.length} 篇', style: styles.listSupporting),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child: Column(
            children: [
              for (var index = 0; index < articles.length; index++) ...[
                ManualArticleRow(
                  article: articles[index],
                  onTap:
                      () => context.push(
                        '/profile/manual/${articles[index].slug}',
                      ),
                ),
                if (index < articles.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ManualEmptyState extends StatelessWidget {
  const _ManualEmptyState();

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          children: [
            Icon(
              RemixIcons.search_eye_line,
              color: colors.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.space8),
            Text('没有找到相关内容', style: styles.formValue),
            const SizedBox(height: AppSpacing.space4),
            Text('可以换一个关键词试试。', style: styles.listSupporting),
          ],
        ),
      ),
    );
  }
}
