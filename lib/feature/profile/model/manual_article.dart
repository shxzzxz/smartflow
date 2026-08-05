class ManualArticle {
  const ManualArticle({
    required this.slug,
    required this.title,
    required this.summary,
    required this.category,
    required this.keywords,
    required this.assetPath,
  });

  final String slug;
  final String title;
  final String summary;
  final String category;
  final List<String> keywords;
  final String assetPath;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final searchableText =
        [title, summary, category, ...keywords].join(' ').toLowerCase();
    return searchableText.contains(normalizedQuery);
  }
}
