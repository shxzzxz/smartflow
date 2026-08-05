import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../model/manual_article.dart';

/// 使用手册分类标签，用于文章页眉。
class ManualCategoryTag extends StatelessWidget {
  const ManualCategoryTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space10,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: AppComponentTokens.selectedContainerOpacity,
        ),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Text(
        label,
        style: context.appTextStyles.badgeLabel.copyWith(color: colors.primary),
      ),
    );
  }
}

/// 手册文章行：标题 + 摘要 + 箭头，与「设置」页行样式一致。
class ManualArticleRow extends StatelessWidget {
  const ManualArticleRow({
    required this.article,
    required this.onTap,
    super.key,
  });

  final ManualArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: styles.formValue),
                  const SizedBox(height: AppSpacing.space4),
                  Text(article.summary, style: styles.listSupporting),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Icon(RemixIcons.arrow_right_s_line, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
