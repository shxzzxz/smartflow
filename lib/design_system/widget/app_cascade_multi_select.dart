import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/spacing.dart';
import 'app_submit_button.dart';

class AppCascadeSelectionNode<T> {
  const AppCascadeSelectionNode({
    required this.value,
    required this.label,
    this.children = const [],
  });

  final T? value;
  final String label;
  final List<AppCascadeSelectionNode<T>> children;

  const AppCascadeSelectionNode.group({
    required this.label,
    required this.children,
  }) : value = null;
}

class AppCascadeSelectionSection<T> {
  const AppCascadeSelectionSection({required this.nodes, this.label});

  final String? label;
  final List<AppCascadeSelectionNode<T>> nodes;
}

Future<Set<T>?> showAppCascadeMultiSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppCascadeSelectionSection<T>> sections,
  required Set<T> selectedValues,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => _AppCascadeMultiSelectSheet<T>(
          title: title,
          sections: sections,
          initialSelectedValues: selectedValues,
        ),
  );
}

class _AppCascadeMultiSelectSheet<T> extends StatefulWidget {
  const _AppCascadeMultiSelectSheet({
    required this.title,
    required this.sections,
    required this.initialSelectedValues,
  });

  final String title;
  final List<AppCascadeSelectionSection<T>> sections;
  final Set<T> initialSelectedValues;

  @override
  State<_AppCascadeMultiSelectSheet<T>> createState() =>
      _AppCascadeMultiSelectSheetState<T>();
}

class _AppCascadeMultiSelectSheetState<T>
    extends State<_AppCascadeMultiSelectSheet<T>> {
  late final Set<T> _allValues = {
    for (final section in widget.sections)
      for (final node in section.nodes) ..._valuesOf(node),
  };
  late final Set<T> _selectedValues = widget.initialSelectedValues.intersection(
    _allValues,
  );
  late List<AppCascadeSelectionNode<T>> _path = _initialPath();

  List<AppCascadeSelectionNode<T>> get _rootNodes => [
    for (final section in widget.sections) ...section.nodes,
  ];

  int get _columnCount => _rootNodes.fold<int>(
    1,
    (depth, node) => depth > _depthOf(node) ? depth : _depthOf(node),
  );

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        AppComponentTokens.selectionSheetMaxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Flexible(
              child:
                  _rootNodes.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space24),
                          child: Text(
                            '暂无可选项',
                            style: context.appTextStyles.inputText,
                          ),
                        ),
                      )
                      : _buildColumns(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(
                label: '确定',
                onPressed:
                    () => Navigator.of(context).pop(Set.of(_selectedValues)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space8,
        AppSpacing.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: context.appTextStyles.subsectionTitle,
            ),
          ),
          TextButton(
            onPressed:
                _selectedValues.length == _allValues.length
                    ? null
                    : () => setState(() {
                      _selectedValues
                        ..clear()
                        ..addAll(_allValues);
                    }),
            child: const Text('全部'),
          ),
          TextButton(
            onPressed:
                _selectedValues.isEmpty
                    ? null
                    : () => setState(_selectedValues.clear),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  Widget _buildColumns(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var depth = 0; depth < _columnCount; depth++) ...[
          if (depth > 0)
            const VerticalDivider(width: AppComponentTokens.outlineWidth),
          Expanded(child: _buildColumn(context, depth)),
        ],
      ],
    );
  }

  Widget _buildColumn(BuildContext context, int depth) {
    if (depth == 0) {
      return ListView(
        children: [
          for (final section in widget.sections) ...[
            if (section.label case final label?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space12,
                  AppSpacing.space12,
                  AppSpacing.space8,
                  AppSpacing.space4,
                ),
                child: Text(label, style: context.appTextStyles.groupTitle),
              ),
            for (final node in section.nodes)
              _buildNodeRow(
                context,
                node,
                active: _isActive(depth, node),
                onTap: () => _activateNode(depth, node),
              ),
          ],
        ],
      );
    }

    final nodes =
        _path.length >= depth
            ? _path[depth - 1].children
            : <AppCascadeSelectionNode<T>>[];
    if (nodes.isEmpty) {
      return Center(
        child: Text(
          '暂无选项',
          textAlign: TextAlign.center,
          style: context.appTextStyles.inputText,
        ),
      );
    }
    return ListView(
      children: [
        for (final node in nodes)
          _buildNodeRow(
            context,
            node,
            active: _isActive(depth, node),
            onTap: () => _activateNode(depth, node),
          ),
      ],
    );
  }

  Widget _buildNodeRow(
    BuildContext context,
    AppCascadeSelectionNode<T> node, {
    required bool active,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final values = _valuesOf(node);
    return Material(
      color: active ? colors.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppComponentTokens.controlMinHeight,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.space4,
                height: AppSpacing.space24,
                child: active ? ColoredBox(color: colors.primary) : null,
              ),
              Checkbox(
                value: _selectionValue(node),
                tristate: true,
                onChanged: values.isEmpty ? null : (_) => _toggleNode(node),
              ),
              Expanded(
                child: Text(
                  node.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.formPlainValue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppCascadeSelectionNode<T>> _initialPath() {
    final path = <AppCascadeSelectionNode<T>>[];
    var nodes = _rootNodes;
    while (nodes.isNotEmpty) {
      final node = nodes.first;
      path.add(node);
      nodes = node.children;
    }
    return path;
  }

  int _depthOf(AppCascadeSelectionNode<T> node) {
    if (node.children.isEmpty) return 1;
    return 1 + node.children.map(_depthOf).reduce((a, b) => a > b ? a : b);
  }

  bool _isActive(int depth, AppCascadeSelectionNode<T> node) =>
      _path.length > depth && identical(_path[depth], node);

  void _activateNode(int depth, AppCascadeSelectionNode<T> node) {
    setState(() {
      _path = _path.take(depth).toList()..add(node);
      var current = node;
      while (current.children.isNotEmpty) {
        current = current.children.first;
        _path.add(current);
      }
    });
  }

  bool? _selectionValue(AppCascadeSelectionNode<T> node) {
    final values = _valuesOf(node);
    final selectedCount = values.where(_selectedValues.contains).length;
    if (selectedCount == 0) return false;
    if (selectedCount == values.length) return true;
    return null;
  }

  void _toggleNode(AppCascadeSelectionNode<T> node) {
    final values = _valuesOf(node);
    final shouldSelect = values.any(
      (value) => !_selectedValues.contains(value),
    );
    setState(() {
      if (shouldSelect) {
        _selectedValues.addAll(values);
      } else {
        _selectedValues.removeAll(values);
      }
    });
  }

  List<T> _valuesOf(AppCascadeSelectionNode<T> node) => [
    if (node.value case final value?) value,
    for (final child in node.children) ..._valuesOf(child),
  ];
}
