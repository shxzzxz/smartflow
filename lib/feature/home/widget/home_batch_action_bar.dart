import 'package:flutter/material.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

class HomeBatchActionBar extends StatelessWidget {
  const HomeBatchActionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.enabled,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onDelete,
    required this.onManageTags,
    super.key,
  });

  final int selectedCount;
  final int totalCount;
  final bool enabled;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final VoidCallback onDelete;
  final VoidCallback onManageTags;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space8,
            vertical: AppSpacing.space4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '已选 $selectedCount/$totalCount 笔',
                  child: Text(
                    '$selectedCount/$totalCount',
                    style: context.appTextStyles.listSupporting,
                  ),
                ),
              ),
              _BatchActionButton(
                label: '全选',
                onPressed:
                    enabled && !allSelected && totalCount > 0
                        ? onSelectAll
                        : null,
              ),
              _BatchActionButton(
                label: '取消全选',
                onPressed: enabled && selectedCount > 0 ? onClearAll : null,
              ),
              _BatchActionButton(
                label: '删除',
                onPressed: enabled && selectedCount > 0 ? onDelete : null,
                foregroundColor: colors.error,
              ),
              _BatchActionButton(
                label: '标签管理',
                onPressed: enabled && selectedCount > 0 ? onManageTags : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.label,
    required this.onPressed,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}
