import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../data/manual_catalog.dart';

class ManualArticlePage extends StatelessWidget {
  const ManualArticlePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final article = findManualArticle(slug);
    if (article == null) {
      return const Scaffold(body: Center(child: Text('手册文章不存在')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(article.assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('文章加载失败'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ManualMarkdown(data: snapshot.data!);
        },
      ),
    );
  }
}

class _ManualMarkdown extends StatelessWidget {
  const _ManualMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = context.appTextStyles;
    final colors = theme.colorScheme;
    return Markdown(
      data: data,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space12,
        AppSpacing.space16,
        AppSpacing.space32,
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h1: styles.pageTitle,
        h2: styles.sectionTitle,
        h3: styles.subsectionTitle,
        p: styles.formPlainValue.copyWith(height: 1.6),
        listBullet: styles.formPlainValue,
        blockquote: styles.listSupporting.copyWith(height: 1.5),
        blockquoteDecoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(
          AppSpacing.space12,
          AppSpacing.space8,
          AppSpacing.space12,
          AppSpacing.space8,
        ),
        a: TextStyle(color: colors.primary),
      ),
    );
  }
}
