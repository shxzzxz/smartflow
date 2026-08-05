import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../data/manual_catalog.dart';
import '../model/manual_article.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  String _query = '';
  String _category = manualCategories.first;

  List<ManualArticle> get _articles =>
      manualArticles.where((article) {
        final categoryMatches =
            _category == '全部' || article.category == _category;
        return categoryMatches && article.matches(_query);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final articles = _articles;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('使用手册')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space8,
          AppSpacing.space16,
          AppSpacing.space32,
        ),
        children: [
          Text('了解 SmartFlow', style: styles.pageTitle),
          const SizedBox(height: AppSpacing.space6),
          Text('从记录第一笔账开始，逐步理解账户、交易和信贷功能。', style: styles.pageSubtitle),
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
          const SizedBox(height: AppSpacing.space12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: manualCategories.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: AppSpacing.space8),
              itemBuilder: (context, index) {
                final category = manualCategories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: category == _category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          if (articles.isEmpty)
            _ManualEmptyState(query: _query)
          else
            AppSurface(
              child: Column(
                children: [
                  for (var index = 0; index < articles.length; index++) ...[
                    _ManualArticleRow(article: articles[index]),
                    if (index < articles.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualArticleRow extends StatelessWidget {
  const _ManualArticleRow({required this.article});

  final ManualArticle article;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space6,
      ),
      title: Text(article.title, style: styles.formValue),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space4),
        child: Text(article.summary, style: styles.listSupporting),
      ),
      trailing: Icon(
        RemixIcons.arrow_right_s_line,
        color: colors.onSurfaceVariant,
      ),
      onTap: () => context.push('/profile/manual/${article.slug}'),
    );
  }
}

class _ManualEmptyState extends StatelessWidget {
  const _ManualEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
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
            Text(
              '可以换一个关键词${query.isEmpty ? '' : '，或切换分类'}。',
              style: styles.listSupporting,
            ),
          ],
        ),
      ),
    );
  }
}
