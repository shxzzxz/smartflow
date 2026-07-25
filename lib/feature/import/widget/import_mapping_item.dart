import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

enum ImportMappingItemAction { map, create, unresolved }

class ImportMappingHeader extends StatelessWidget {
  const ImportMappingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.appTextStyles.listSupporting;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space8,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('来源', style: style)),
          const SizedBox(width: AppSpacing.space8),
          SizedBox(
            width: AppSpacing.space48,
            child: Text('操作', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            flex: 5,
            child: Text('映射到', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class ImportMappingItem extends StatelessWidget {
  const ImportMappingItem({
    required this.sourceLabel,
    required this.sourceKindLabel,
    required this.targetLabel,
    required this.action,
    this.targetKindLabel,
    this.operationLabel,
    this.onTap,
    super.key,
  });

  final String sourceLabel;
  final String sourceKindLabel;
  final String targetLabel;
  final ImportMappingItemAction action;
  final String? targetKindLabel;
  final String? operationLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final createsTarget = action == ImportMappingItemAction.create;
    final isUnresolved = action == ImportMappingItemAction.unresolved;
    final resolvedOperationLabel =
        operationLabel ??
        switch (action) {
          ImportMappingItemAction.map => '映射',
          ImportMappingItemAction.create => '新增',
          ImportMappingItemAction.unresolved => '待处理',
        };
    final resolvedTargetLabel =
        targetLabel.trim().isEmpty ? '待配置' : targetLabel;
    return Semantics(
      button: onTap != null,
      label:
          createsTarget
              ? '$sourceLabel，导入时新建 $resolvedTargetLabel'
              : isUnresolved
              ? '$sourceLabel，映射到 $resolvedTargetLabel'
              : '$sourceLabel，映射到 $resolvedTargetLabel',
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
                flex: 4,
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
              const SizedBox(width: AppSpacing.space8),
              SizedBox(
                width: AppSpacing.space48,
                child: Text(
                  resolvedOperationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.listSupporting.copyWith(
                    color:
                        isUnresolved
                            ? colors.error
                            : createsTarget
                            ? colors.primary
                            : colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      resolvedTargetLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: context.appTextStyles.detailValue.copyWith(
                        color:
                            isUnresolved || createsTarget
                                ? colors.primary
                                : colors.onSurface,
                      ),
                    ),
                    if (targetKindLabel != null &&
                        targetKindLabel!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        targetKindLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: context.appTextStyles.listSupporting,
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
