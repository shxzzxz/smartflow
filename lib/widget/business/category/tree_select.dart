import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
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
                    ListTile(
                      leading: BusinessIconBubble(
                        size: AppSpacing.space40,
                        child: BusinessIcon(
                          iconKey: node.account.iconKey,
                          size: AppSpacing.space24,
                        ),
                      ),
                      title: Text(node.account.name),
                      trailing:
                          node.children.isEmpty
                              ? null
                              : IconButton(
                                tooltip:
                                    _expandedId == node.account.id
                                        ? '收起子分类'
                                        : '展开子分类',
                                icon: Icon(
                                  _expandedId == node.account.id
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _expandedId =
                                              _expandedId == node.account.id
                                                  ? null
                                                  : node.account.id,
                                    ),
                              ),
                      enabled: true,
                      onTap:
                          widget.disabledIds.contains(node.account.id)
                              ? null
                              : () => Navigator.of(context).pop(node.account),
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
                                onTap: () => Navigator.of(context).pop(child),
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
