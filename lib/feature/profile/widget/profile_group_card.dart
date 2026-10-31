import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/icon/business_icon_bubble.dart';
import '../presentation/profile_menu.dart';

class ProfileGroupCard extends StatelessWidget {
  const ProfileGroupCard({required this.group, super.key});

  final ProfileMenuGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: group.title),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child: switch (group.layout) {
            ProfileGroupLayout.grid => _ProfileGrid(entries: group.entries),
            ProfileGroupLayout.list => _ProfileList(entries: group.entries),
          },
        ),
      ],
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.entries});

  final List<ProfileMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final gap = AppSpacing.space4;
        final minTileWidth =
            AppComponentTokens.profileGridMinTileWidth *
            textScale.clamp(1, 1.5);
        final maxByWidth = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(3, 5)
            .toInt();
        final columns = profileGridColumnCount(
          entryCount: entries.length,
          maxColumns: maxByWidth,
        );
        final tileHeight = MediaQuery.textScalerOf(context)
            .scale(AppComponentTokens.profileGridTileMainExtent)
            .clamp(
              AppComponentTokens.profileGridTileMainExtent,
              AppComponentTokens.profileGridTileMainExtent * 1.5,
            )
            .toDouble();
        final rows = (entries.length / columns).ceil();
        final cellWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final height = rows * tileHeight + (rows - 1) * gap;

        return SizedBox(
          height: height,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: tileHeight,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Semantics(
                button: true,
                label: entry.title,
                child: BusinessIconTile(
                  extent: cellWidth,
                  onTap: entry.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                      vertical: AppSpacing.space8,
                    ),
                    child: BusinessIconBubble(
                      size: AppSpacing.space40,
                      label: entry.title,
                      labelSpacing: AppSpacing.space8,
                      bubbleColor: Theme.of(context).colorScheme.primary
                          .withValues(
                            alpha: AppComponentTokens.selectedContainerOpacity,
                          ),
                      iconColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        profileIconFor(entry.iconKey),
                        size: AppSpacing.space24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.entries});

  final List<ProfileMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _ProfileListRow(entry: entries[index]),
          if (index < entries.length - 1) const AppListDivider(),
        ],
      ],
    );
  }
}

class _ProfileListRow extends StatelessWidget {
  const _ProfileListRow({required this.entry});

  final ProfileMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space10,
        ),
        child: Row(
          key: ValueKey('profile-entry-row-${entry.title}'),
          children: [
            BusinessIconBubble(
              size: AppSpacing.space32,
              bubbleColor: colors.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              ),
              iconColor: colors.primary,
              child: Icon(
                profileIconFor(entry.iconKey),
                size: AppSpacing.space24,
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              flex: 3,
              child: Text(entry.title, style: context.appTextStyles.listTitle),
            ),
            if (entry.value case final value?) ...[
              const SizedBox(width: AppSpacing.space8),
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Text(
                  key: ValueKey('profile-entry-value-${entry.title}'),
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.appTextStyles.listSupporting,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: AppSpacing.space20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

IconData profileIconFor(String iconKey) => switch (iconKey) {
  'category' => RemixIcons.apps_2_line,
  'tag' => RemixIcons.price_tag_3_line,
  'counterparty' => RemixIcons.user_shared_line,
  'amortization' => RemixIcons.calendar_schedule_line,
  'calculator' => RemixIcons.calculator_line,
  'settings' => RemixIcons.settings_3_line,
  'installment_product' => RemixIcons.file_list_3_line,
  'reference_rate' => RemixIcons.percent_line,
  'import' => RemixIcons.file_excel_2_line,
  'cleanup' => RemixIcons.delete_bin_6_line,
  'backup' => RemixIcons.shield_check_line,
  'manual' => RemixIcons.book_open_line,
  'version' => RemixIcons.download_cloud_2_line,
  'components' => Icons.widgets_outlined,
  'logs' => RemixIcons.file_list_3_line,
  _ => RemixIcons.question_line,
};
