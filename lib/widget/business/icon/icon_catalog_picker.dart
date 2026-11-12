import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/widget/app_choice_chip_group.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';

import 'business_icon.dart';
import 'business_icon_bubble.dart';
import 'icon_choice_grid.dart';

class IconCatalogPicker extends StatefulWidget {
  const IconCatalogPicker({
    required this.usage,
    required this.selectedRef,
    required this.onChanged,
    super.key,
  });

  final BusinessIconUsage usage;
  final String? selectedRef;
  final ValueChanged<String> onChanged;

  @override
  State<IconCatalogPicker> createState() => _IconCatalogPickerState();
}

class _IconCatalogPickerState extends State<IconCatalogPicker> {
  var _query = '';
  String? _selectedGroupIdentity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scope = BusinessIconScope.of(context);
    final type = widget.usage == BusinessIconUsage.account
        ? BusinessIconType.account
        : BusinessIconType.category;
    final selectedSpec = scope.resolve(widget.selectedRef, widget.usage);
    final selectedGroup = selectedSpec == null
        ? null
        : scope.groupForRef(selectedSpec.ref);
    final fallbackGroup = selectedGroup ?? scope.defaultGroupFor(type);
    final effectiveGroup = scope.groupsFor(type).where((group) {
      final expectedIdentity =
          _selectedGroupIdentity ?? fallbackGroup?.identity;
      return group.identity == expectedIdentity;
    }).firstOrNull;
    final searching = _query.trim().isNotEmpty;
    final specs = scope.search(
      usage: widget.usage,
      groupId: searching ? null : effectiveGroup?.id,
      origin: searching ? null : effectiveGroup?.origin,
      query: _query,
    );
    final choices = [
      for (final spec in specs)
        IconChoiceGridItem(
          iconKey: spec.ref.id,
          label: searching
              ? '${spec.label} · ${scope.groupForRef(spec.ref)?.name ?? spec.groupId}'
              : spec.label,
          iconBuilder: (context, size) => BusinessIcon(
            iconRef: spec.ref.id,
            usage: widget.usage,
            size: size,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                child: Center(
                  child: BusinessIconBubble(
                    size: 32,
                    child: BusinessIcon(
                      iconRef: widget.selectedRef,
                      usage: widget.usage,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: context.appTextStyles.inputText,
                decoration: InputDecoration(
                  hintText: '搜索图标',
                  hintStyle: context.appTextStyles.inputText.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(RemixIcons.search_line),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        if (!searching && effectiveGroup != null)
          AppChoiceChipGroup<String>(
            key: const ValueKey('business-icon-group-choice'),
            selected: effectiveGroup.identity,
            size: AppChoiceChipSize.compact,
            options: [
              for (final group in scope.groupsFor(type))
                AppChoiceChipOption(value: group.identity, label: group.name),
            ],
            onChanged: (identity) =>
                setState(() => _selectedGroupIdentity = identity),
          ),
        if (!searching) const SizedBox(height: AppSpacing.space12),
        if (choices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('没有匹配的图标'),
          )
        else
          IconChoiceGrid(
            choices: choices,
            selectedKey: selectedSpec?.ref.id,
            onChanged: widget.onChanged,
            maxVisibleRows: 3,
          ),
      ],
    );
  }
}
