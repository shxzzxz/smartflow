import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';

/// 首页批量模式的底部动作栏。占用底部导航栏的槽位，因此复用导航栏的高度、
/// 图标字形和分割线，让两者互换时几何连续；选中计数由页头承载，这里只放动作。
class HomeBatchActionBar extends StatefulWidget {
  const HomeBatchActionBar({
    required this.selectedCount,
    required this.enabled,
    required this.onDelete,
    required this.onManageTags,
    super.key,
    this.processing = false,
  });

  final int selectedCount;
  final bool enabled;
  final bool processing;
  final VoidCallback onDelete;
  final VoidCallback onManageTags;

  @override
  State<HomeBatchActionBar> createState() => _HomeBatchActionBarState();
}

class _HomeBatchActionBarState extends State<HomeBatchActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.durationFast,
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canOperate =
        widget.enabled && !widget.processing && widget.selectedCount > 0;

    return Material(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _entrance,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_entrance),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TopEdge(processing: widget.processing),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppComponentTokens.navigationBarHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space8,
                    ),
                    // 动作项撑满栏高，保证触控盒不小于 48。
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BatchAction(
                            icon: RemixIcons.price_tag_3_line,
                            label: '标签',
                            onPressed: canOperate ? widget.onManageTags : null,
                          ),
                          _BatchAction(
                            icon: RemixIcons.delete_bin_line,
                            label: '删除',
                            destructive: true,
                            onPressed: canOperate ? widget.onDelete : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶边固定 2pt：空闲时画分割线，处理中换成进度条，避免栏高在两种状态间跳动。
class _TopEdge extends StatelessWidget {
  const _TopEdge({required this.processing});

  final bool processing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: AppSpacing.space2,
      child:
          processing
              ? const LinearProgressIndicator(minHeight: AppSpacing.space2)
              : Align(
                alignment: Alignment.topCenter,
                child: ColoredBox(
                  color: colors.outlineVariant.withValues(
                    alpha: AppComponentTokens.mutedOutlineOpacity,
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: AppComponentTokens.outlineWidth,
                  ),
                ),
              ),
    );
  }
}

class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// 传 null 表示当前不可操作。
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseColor = destructive ? colors.error : colors.onSurface;
    final color =
        onPressed == null
            ? baseColor.withValues(
              alpha: AppComponentTokens.disabledContentOpacity,
            )
            : baseColor;

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Semantics(
            button: true,
            enabled: onPressed != null,
            label: label,
            excludeSemantics: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: AppComponentTokens.bottomBarIconSize,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  label,
                  style: context.appTextStyles.navigationLabel.copyWith(
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
