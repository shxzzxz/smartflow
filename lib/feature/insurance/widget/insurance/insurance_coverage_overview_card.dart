import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_surface.dart';
import '../../presentation/insurance_coverage_field.dart';
import '../../presentation/insurance_presentation.dart';

class InsuranceCoverageOverviewCard extends StatelessWidget {
  const InsuranceCoverageOverviewCard({
    required this.summary,
    required this.highlights,
    super.key,
    this.title,
    this.onTap,
    this.onEditField,
    this.enabled = true,
    this.waitingPeriodDescription,
    this.exclusionsDescription,
    this.showResponsibilitiesLink = false,
  });

  final String? summary;
  final String? highlights;
  final String? title;
  final VoidCallback? onTap;
  final ValueChanged<InsuranceCoverageField>? onEditField;
  final bool enabled;
  final String? waitingPeriodDescription;
  final String? exclusionsDescription;
  final bool showResponsibilitiesLink;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final editing = onEditField != null;
    final summaryText = summary?.trim() ?? '';
    final waitingPeriod = waitingPeriodDescription?.trim() ?? '';
    final highlightLines = insuranceTextLines(highlights);
    final exclusions = exclusionsDescription?.trim() ?? '';
    return AppSurface(
      child: InkWell(
        onTap: enabled && !editing ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title case final heading?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space12,
                  AppSpacing.space16,
                  AppSpacing.space4,
                ),
                child: Row(
                  children: [
                    Icon(
                      RemixIcons.shield_check_fill,
                      size: AppSpacing.space18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: Text(
                        heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: styles.subsectionTitleStrong,
                      ),
                    ),
                  ],
                ),
              ),
            _CoverageSection(
              label: InsuranceCoverageField.summary.label,
              onTap: _editCallback(InsuranceCoverageField.summary),
              child: Text(
                summaryText.isEmpty && editing ? '点击填写' : summaryText,
                style: styles.listSupporting,
              ),
            ),
            _CoverageSection(
              label: InsuranceCoverageField.highlights.label,
              onTap: _editCallback(InsuranceCoverageField.highlights),
              child: highlightLines.isEmpty && editing
                  ? Text('点击填写', style: styles.listSupporting)
                  : _CoverageHighlights(lines: highlightLines),
            ),
            if (editing || waitingPeriod.isNotEmpty)
              _WaitingPeriodRow(
                value: waitingPeriod.isEmpty ? '点击填写' : waitingPeriod,
                onTap: _editCallback(InsuranceCoverageField.waitingPeriod),
              ),
            if (editing || exclusions.isNotEmpty)
              _CoverageSection(
                label: InsuranceCoverageField.exclusions.label,
                onTap: _editCallback(InsuranceCoverageField.exclusions),
                child: Text(
                  exclusions.isEmpty ? '点击填写' : exclusions,
                  style: styles.listSupporting,
                ),
              ),
            if (showResponsibilitiesLink)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                  vertical: AppSpacing.space12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '具体保障项目',
                        style: styles.onPrimaryTinyStrong.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Text('查看全部', style: styles.listSupporting),
                    const SizedBox(width: AppSpacing.space4),
                    Icon(
                      RemixIcons.arrow_right_s_line,
                      size: AppSpacing.space16,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _editCallback(InsuranceCoverageField field) {
    final callback = onEditField;
    if (!enabled || callback == null) return null;
    return () => callback(field);
  }
}

class _CoverageSection extends StatelessWidget {
  const _CoverageSection({
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: context.appTextStyles.onPrimaryTinyStrong.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            child,
          ],
        ),
      ),
    );
  }
}

class _WaitingPeriodRow extends StatelessWidget {
  const _WaitingPeriodRow({required this.value, this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              InsuranceCoverageField.waitingPeriod.label,
              style: styles.onPrimaryTinyStrong.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.space16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: styles.listSupporting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageHighlights extends StatelessWidget {
  const _CoverageHighlights({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space2),
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: AppSpacing.space12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          RemixIcons.check_line,
                          size: AppSpacing.space8,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  lines[index],
                  style: context.appTextStyles.listSupporting,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
