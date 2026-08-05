import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../data/manual_catalog.dart';
import '../model/manual_article.dart';
import '../widget/manual_markdown.dart';
import '../widget/manual_sheets.dart';
import '../widget/manual_widgets.dart';

class ManualArticlePage extends StatefulWidget {
  const ManualArticlePage({required this.slug, super.key});

  final String slug;

  @override
  State<ManualArticlePage> createState() => _ManualArticlePageState();
}

class _ManualArticlePageState extends State<ManualArticlePage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _headingKeys = {};
  String? _content;
  Object? _loadError;
  List<ManualHeading> _headings = const [];

  ManualArticle? get _article => findManualArticle(widget.slug);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final article = _article;
    if (article == null) {
      return;
    }
    try {
      final data = await rootBundle.loadString(article.assetPath, cache: false);
      if (!mounted) {
        return;
      }
      final content = stripLeadingH1(data);
      final headings = parseManualHeadings(content);
      setState(() {
        _content = content;
        _headings = headings;
        _headingKeys
          ..clear()
          ..addEntries(
            headings.map((heading) => MapEntry(heading.key, GlobalKey())),
          );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = error);
    }
  }

  void _scrollToHeading(String key) {
    final target = _headingKeys[key]?.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openArticleDirectory() {
    final article = _article;
    if (article == null) {
      return;
    }
    showManualArticleDirectorySheet(
      context: context,
      currentSlug: article.slug,
      onSelect: (slug) {
        if (slug != article.slug) {
          context.push('/profile/manual/$slug');
        }
      },
    );
  }

  void _openArticleToc() {
    if (_headings.isEmpty) {
      return;
    }
    showManualArticleTocSheet(
      context: context,
      headings: _headings,
      onSelect: _scrollToHeading,
    );
  }

  void _handleTapLink(String text, String? href, String title) {
    if (href == null) {
      return;
    }
    if (href.startsWith('/')) {
      context.push(href);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('暂不支持打开外部链接')));
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    if (article == null) {
      return const Scaffold(body: Center(child: Text('手册文章不存在')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '文章目录',
          icon: const Icon(RemixIcons.menu_2_line),
          onPressed: _openArticleDirectory,
        ),
        title: Text(article.title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '本页目录',
            icon: const Icon(RemixIcons.list_ordered_2),
            onPressed: _headings.isEmpty ? null : _openArticleToc,
          ),
        ],
      ),
      body: _buildBody(article),
    );
  }

  Widget _buildBody(ManualArticle article) {
    if (_loadError != null) {
      return const Center(child: Text('文章加载失败'));
    }
    final content = _content;
    if (content == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final styles = context.appTextStyles;
    final related =
        manualArticles
            .where(
              (a) => a.slug != article.slug && a.category == article.category,
            )
            .toList();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space20,
        AppSpacing.space20,
        AppSpacing.space32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManualArticleIntro(article: article),
          ManualMarkdownBody(
            data: content,
            headingKeys: _headingKeys,
            onTapLink: _handleTapLink,
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space24),
            Text('相关文章', style: styles.groupTitle),
            const SizedBox(height: AppSpacing.space8),
            AppSurface(
              child: Column(
                children: [
                  for (var index = 0; index < related.length; index++) ...[
                    ManualArticleRow(
                      article: related[index],
                      onTap:
                          () => context.push(
                            '/profile/manual/${related[index].slug}',
                          ),
                    ),
                    if (index < related.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualArticleIntro extends StatelessWidget {
  const _ManualArticleIntro({required this.article});

  final ManualArticle article;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManualCategoryTag(label: article.category),
        const SizedBox(height: AppSpacing.space12),
        Text(article.title, style: styles.pageTitle),
        if (article.summary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space8),
          Text(
            article.summary,
            style: styles.pageSubtitle.copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}
