import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/spacing.dart';

enum AppRegionLevel { province, city, district }

class AppRegionNode {
  const AppRegionNode({
    required this.code,
    required this.name,
    this.children = const [],
  });

  final String code;
  final String name;
  final List<AppRegionNode> children;
}

class AppRegionSelection {
  AppRegionSelection(List<AppRegionNode> path) : path = List.unmodifiable(path);

  final List<AppRegionNode> path;
  List<String> get codes => [for (final node in path) node.code];
  String get label => path.map((node) => node.name).join(' / ');
}

Future<AppRegionSelection?> showAppRegionPickerSheet({
  required BuildContext context,
  required List<AppRegionNode> regions,
  AppRegionLevel level = AppRegionLevel.district,
  List<String> selectedCodes = const [],
  String title = '选择地区',
}) {
  return showModalBottomSheet<AppRegionSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => AppRegionPickerSheet(
      regions: regions,
      level: level,
      selectedCodes: selectedCodes,
      title: title,
      onSelected: (selection) => Navigator.of(context).pop(selection),
    ),
  );
}

/// Parent rows navigate; only a row at [level] completes the selection.
class AppRegionPickerSheet extends StatefulWidget {
  const AppRegionPickerSheet({
    required this.regions,
    required this.onSelected,
    super.key,
    this.level = AppRegionLevel.district,
    this.selectedCodes = const [],
    this.title = '选择地区',
  });

  final List<AppRegionNode> regions;
  final AppRegionLevel level;
  final List<String> selectedCodes;
  final String title;
  final ValueChanged<AppRegionSelection> onSelected;

  @override
  State<AppRegionPickerSheet> createState() => _AppRegionPickerSheetState();
}

class _AppRegionPickerSheetState extends State<AppRegionPickerSheet> {
  final List<AppRegionNode> _path = [];
  var _activeLevel = 0;

  @override
  void initState() {
    super.initState();
    var nodes = widget.regions;
    for (final code in widget.selectedCodes.take(widget.level.index + 1)) {
      final node = nodes.where((node) => node.code == code).firstOrNull;
      if (node == null) break;
      _path.add(node);
      nodes = node.children;
    }
    _activeLevel = _path.isEmpty
        ? 0
        : (_path.length < widget.level.index + 1
              ? _path.length
              : widget.level.index);
  }

  List<AppRegionNode> get _nodes =>
      _activeLevel == 0 ? widget.regions : _path[_activeLevel - 1].children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        AppComponentTokens.selectionSheetMaxHeightFactor;
    return SizedBox(
      height: maxHeight,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: context.appTextStyles.subsectionTitleStrong,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭地区选择',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
              ),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index <= _activeLevel || index < _path.length;
                    index++
                  )
                    TextButton(
                      key: ValueKey('region-level-$index'),
                      onPressed: () => setState(() => _activeLevel = index),
                      child: Text(
                        index < _path.length ? _path[index].name : '请选择',
                        style: context.appTextStyles.formValue.copyWith(
                          color: _activeLevel == index
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _nodes.isEmpty
                  ? Center(
                      child: Text(
                        '暂无可选地区',
                        style: context.appTextStyles.listSupporting,
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('region-options-$_activeLevel'),
                      itemCount: _nodes.length,
                      itemBuilder: (context, index) {
                        final node = _nodes[index];
                        final selected =
                            _path.length > _activeLevel &&
                            _path[_activeLevel].code == node.code;
                        return ListTile(
                          key: ValueKey('region-option-${node.code}'),
                          title: Text(
                            node.name,
                            style: context.appTextStyles.formValue,
                          ),
                          selected: selected,
                          trailing: selected
                              ? Icon(Icons.check, color: colors.primary)
                              : _activeLevel < widget.level.index
                              ? const Icon(Icons.chevron_right)
                              : null,
                          onTap: () => _select(node),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(AppRegionNode node) {
    final next = [..._path.take(_activeLevel), node];
    if (_activeLevel == widget.level.index) {
      widget.onSelected(AppRegionSelection(next));
      return;
    }
    setState(() {
      _path
        ..clear()
        ..addAll(next);
      _activeLevel++;
    });
  }
}
