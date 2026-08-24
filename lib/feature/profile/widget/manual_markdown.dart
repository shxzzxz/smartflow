import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/token/typography.dart';

/// 文章内一个可跳转的章节标题（目录项）。
class ManualHeading {
  const ManualHeading({
    required this.text,
    required this.level,
    required this.key,
  });

  final String text;

  /// 标题层级，2 对应 `##`，3 对应 `###`。
  final int level;

  /// 用于定位标题的唯一 key。
  final String key;
}

/// 生成标题的唯一 key；同一标题出现多次时追加序号。
String manualHeadingKey(String text, int occurrence) =>
    occurrence <= 1 ? text : '$text #$occurrence';

/// 从 markdown 源码解析 `##`/`###` 标题，按出现顺序返回。
List<ManualHeading> parseManualHeadings(String data) {
  final headings = <ManualHeading>[];
  final occurrences = <String, int>{};
  for (final line in data.split('\n')) {
    final trimmed = line.trimLeft();
    final int level;
    final String raw;
    if (trimmed.startsWith('### ')) {
      level = 3;
      raw = trimmed.substring(4);
    } else if (trimmed.startsWith('## ')) {
      level = 2;
      raw = trimmed.substring(3);
    } else {
      continue;
    }
    final text = _stripInlineMarkers(raw.trim());
    if (text.isEmpty) {
      continue;
    }
    final count = (occurrences[text] ?? 0) + 1;
    occurrences[text] = count;
    headings.add(
      ManualHeading(
        text: text,
        level: level,
        key: manualHeadingKey(text, count),
      ),
    );
  }
  return headings;
}

/// 去掉 markdown 开头的 `# 一级标题`，避免与页内大标题重复。
String stripLeadingH1(String data) {
  var lines = data.split('\n');
  if (lines.isEmpty) {
    return data;
  }
  final first = lines.first.trimLeft();
  if (!first.startsWith('# ')) {
    return data;
  }
  lines = lines.sublist(1);
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines = lines.sublist(1);
  }
  return lines.join('\n');
}

String _stripInlineMarkers(String text) =>
    text.replaceAll(RegExp(r'[*_`~]'), '').trim();

/// 按手册排版规范渲染 markdown 正文。
///
/// 通过 [headingKeys] 给 h2/h3 挂锚点，供「本页目录」滚动定位；
/// 通过自定义 blockquote builder 把 `> 💡` / `> ⚠️` 渲染成提示卡片。
class ManualMarkdownBody extends StatelessWidget {
  const ManualMarkdownBody({
    required this.data,
    required this.headingKeys,
    this.onTapLink,
    super.key,
  });

  final String data;
  final Map<String, GlobalKey> headingKeys;
  final void Function(String text, String? href, String title)? onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = context.appTextStyles;
    final colors = theme.colorScheme;
    final bodyStyle = styles.formValue.copyWith(height: 1.7);
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: AppTypography.fontSizeSm - 1,
      color: colors.primary,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.6),
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: onTapLink,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h2: styles.sectionTitle.copyWith(
          height: AppTypography.lineHeightTitle,
          fontSize: AppTypography.fontSizeLg,
        ),
        h2Padding: const EdgeInsets.only(top: AppSpacing.space28),
        h3: styles.subsectionTitle.copyWith(
          height: AppTypography.lineHeightTitle,
        ),
        h3Padding: const EdgeInsets.only(top: AppSpacing.space20),
        p: bodyStyle,
        pPadding: const EdgeInsets.only(top: AppSpacing.space8),
        strong: bodyStyle.copyWith(fontWeight: AppTypography.strongWeight),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: bodyStyle,
        listBulletPadding: const EdgeInsets.only(right: AppSpacing.space8),
        blockSpacing: AppSpacing.space8,
        checkbox: TextStyle(
          color: colors.primary,
          fontSize: AppTypography.fontSizeLg,
        ),
        listIndent: AppSpacing.space24,
        blockquote: styles.detailValue.copyWith(
          height: 1.6,
          color: colors.onSurfaceVariant,
        ),
        blockquoteDecoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(
          AppSpacing.space12,
          AppSpacing.space10,
          AppSpacing.space12,
          AppSpacing.space10,
        ),
        code: codeStyle,
        codeblockPadding: const EdgeInsets.all(AppSpacing.space12),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        a: TextStyle(
          color: colors.primary,
          decoration: TextDecoration.underline,
          decorationColor: colors.primary,
        ),
        tableHead: styles.listTitle.copyWith(
          fontWeight: AppTypography.strongWeight,
        ),
        tableBody: styles.formValue.copyWith(
          fontSize: AppTypography.fontSizeSm,
          height: 1.5,
        ),
        tableHeadCellsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space10,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space10,
        ),
        tableHeadCellsDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        tableBorder: TableBorder.all(color: colors.outlineVariant),
        tablePadding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      ),
      builders: {
        'h2': _ManualHeadingBuilder(
          headingKeys: headingKeys,
          padding: const EdgeInsets.only(top: AppSpacing.space28),
        ),
        'h3': _ManualHeadingBuilder(
          headingKeys: headingKeys,
          padding: const EdgeInsets.only(top: AppSpacing.space20),
        ),
        'blockquote': _ManualBlockquoteBuilder(),
      },
    );
  }
}

class _ManualHeadingBuilder extends MarkdownElementBuilder {
  _ManualHeadingBuilder({required this.headingKeys, required this.padding});

  final Map<String, GlobalKey> headingKeys;
  final EdgeInsets padding;
  final Map<String, int> _occurrences = {};
  String _currentKey = '';

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    final text = element.textContent.trim();
    final count = (_occurrences[text] ?? 0) + 1;
    _occurrences[text] = count;
    _currentKey = manualHeadingKey(text, count);
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final key = headingKeys[_currentKey];
    if (key == null) {
      return null;
    }
    return KeyedSubtree(
      key: key,
      child: Padding(
        padding: padding,
        child: Text(
          element.textContent.trim(),
          style: preferredStyle ?? parentStyle,
        ),
      ),
    );
  }
}

class _ManualBlockquoteBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final callout = _calloutOf(element.textContent.trim());
    if (callout == null) {
      return null;
    }
    final colors = Theme.of(context).colorScheme;
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          callout.icon,
          size: 20,
          color: callout.warning
              ? (themeExtension?.warning ?? colors.primary)
              : colors.primary,
        ),
        const SizedBox(width: AppSpacing.space8),
        Expanded(
          child: Text(
            callout.text,
            style: (preferredStyle ?? parentStyle)?.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _Callout {
  const _Callout({
    required this.icon,
    required this.text,
    required this.warning,
  });

  final IconData icon;
  final String text;
  final bool warning;
}

_Callout? _calloutOf(String raw) {
  final trimmed = raw.trim();
  final tipPattern = RegExp(r'^💡\s*');
  final warningPattern = RegExp(r'^⚠️?\s*');
  if (tipPattern.hasMatch(trimmed)) {
    return _Callout(
      icon: RemixIcons.lightbulb_flash_line,
      text: trimmed.replaceFirst(tipPattern, '').trim(),
      warning: false,
    );
  }
  if (warningPattern.hasMatch(trimmed)) {
    return _Callout(
      icon: RemixIcons.alarm_warning_line,
      text: trimmed.replaceFirst(warningPattern, '').trim(),
      warning: true,
    );
  }
  return null;
}
