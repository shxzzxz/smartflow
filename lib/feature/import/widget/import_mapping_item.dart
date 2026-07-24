import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

enum ImportMappingItemAction { map, create }

class ImportMappingItem extends StatelessWidget {
  const ImportMappingItem({
    required this.sourceLabel,
    required this.sourceKindLabel,
    required this.targetLabel,
    required this.action,
    this.onTap,
    super.key,
  });

  final String sourceLabel;
  final String sourceKindLabel;
  final String targetLabel;
  final ImportMappingItemAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final createsTarget = action == ImportMappingItemAction.create;
    return Semantics(
      button: onTap != null,
      label:
          createsTarget
              ? '$sourceLabel，导入时新建 $targetLabel'
              : '$sourceLabel，映射到 $targetLabel',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.listTitle,
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      sourceKindLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.listSupporting,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space10),
              Icon(
                RemixIcons.arrow_right_line,
                size: AppSpacing.space18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.space10),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        targetLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: context.appTextStyles.detailValue.copyWith(
                          color:
                              createsTarget ? colors.primary : colors.onSurface,
                        ),
                      ),
                    ),
                    if (createsTarget) ...[
                      const SizedBox(width: AppSpacing.space4),
                      Icon(
                        RemixIcons.add_circle_line,
                        size: AppSpacing.space18,
                        color: colors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
