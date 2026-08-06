import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../icon/business_icon.dart';
import '../icon/business_icon_bubble.dart';

class TreeSelect extends StatefulWidget {
  const TreeSelect({
    required this.nodes,
    this.disabledIds = const {},
    super.key,
  });

  final List<CategoryNode> nodes;
  final Set<String> disabledIds;

  @override
  State<TreeSelect> createState() => _TreeSelectState();
}

class _TreeSelectState extends State<TreeSelect> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space20,
                0,
                AppSpacing.space20,
                AppSpacing.space8,
              ),
              child: Text(
                '选择支出分类',
                style: context.appTextStyles.sectionTitleStrong,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final node in widget.nodes) ...[
                    _TreeSelectNodeTile(
                      node: node,
                      disabled: widget.disabledIds.contains(node.account.id),
                      expanded: _expandedId == node.account.id,
                      onSelect: () => Navigator.of(context).pop(node.account),
                      onToggle:
                          () => setState(
                            () =>
                                _expandedId =
                                    _expandedId == node.account.id
                                        ? null
                                        : node.account.id,
                          ),
                    ),
                    if (_expandedId == node.account.id)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.space40,
                        ),
                        child: Column(
                          children: [
                            for (final child in node.children)
                              ListTile(
                                leading: BusinessIconBubble(
                                  size: AppSpacing.space40,
                                  child: BusinessIcon(
                                    iconKey: child.iconKey,
                                    size: AppSpacing.space24,
                                  ),
                                ),
                                title: Text(child.name),
                                enabled: !widget.disabledIds.contains(child.id),
                                onTap:
                                    widget.disabledIds.contains(child.id)
                                        ? null
                                        : () =>
                                            Navigator.of(context).pop(child),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeSelectNodeTile extends StatelessWidget {
  const _TreeSelectNodeTile({
    required this.node,
    required this.disabled,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
  });

  final CategoryNode node;
  final bool disabled;
  final bool expanded;
  final VoidCallback onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleColor =
        disabled
            ? colors.onSurface.withValues(
              alpha: AppComponentTokens.disabledContentOpacity,
            )
            : null;
    return SizedBox(
      height: kMinInteractiveDimension,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: disabled ? null : onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
                child: Row(
                  children: [
                    BusinessIconBubble(
                      size: AppSpacing.space40,
                      child: BusinessIcon(
                        iconKey: node.account.iconKey,
                        size: AppSpacing.space24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Text(
                        node.account.name,
                        style:
                            titleColor == null
                                ? null
                                : TextStyle(color: titleColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (node.children.isNotEmpty)
            IconButton(
              tooltip: expanded ? '收起子分类' : '展开子分类',
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: onToggle,
            )
          else
            const SizedBox(width: AppSpacing.space48),
        ],
      ),
    );
  }
}
