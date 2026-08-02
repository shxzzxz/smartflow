import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/token/spacing.dart';

import 'business_icon.dart';
import 'icon_choice_grid.dart';

class IconCatalogPicker extends StatefulWidget {
  const IconCatalogPicker({
    required this.usage,
    required this.selectedKey,
    required this.onChanged,
    super.key,
  });

  final BusinessIconUsage usage;
  final String? selectedKey;
  final ValueChanged<String> onChanged;

  @override
  State<IconCatalogPicker> createState() => _IconCatalogPickerState();
}

class _IconCatalogPickerState extends State<IconCatalogPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final specs = searchBusinessIconSpecs(usage: widget.usage, query: _query);
    final choices = [
      for (final spec in specs)
        IconChoiceGridItem(
          iconKey: spec.iconKey,
          label: spec.label,
          iconBuilder:
              (context, size) =>
                  BusinessIcon(iconKey: spec.iconKey, size: size),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: '搜索图标',
            prefixIcon: Icon(RemixIcons.search_line),
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        if (choices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('没有匹配的图标'),
          )
        else
          IconChoiceGrid(
            choices: choices,
            selectedKey: widget.selectedKey,
            onChanged: widget.onChanged,
            maxVisibleRows: 3,
          ),
      ],
    );
  }
}
