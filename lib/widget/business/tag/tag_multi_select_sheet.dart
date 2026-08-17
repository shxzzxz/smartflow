import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'tag_search_field.dart';

class TagMultiSelectResult {
  const TagMultiSelectResult({
    required this.selectedTagIds,
    required this.untaggedOnly,
  });

  final Set<String> selectedTagIds;
  final bool untaggedOnly;
}

/// 标签多选弹窗。[allowCreate] 开启「新建标签」入口（录入场景）；
/// [allowUntagged] 开启「未打标签」互斥项（筛选场景），
/// 此时 [untaggedOnly] 传入当前筛选的未打标签状态。
Future<TagMultiSelectResult?> showTagMultiSelectSheet({
  required BuildContext context,
  required List<TagView> tags,
  required Set<String> selectedIds,
  bool untaggedOnly = false,
  bool allowCreate = false,
  bool allowUntagged = false,
}) {
  return showModalBottomSheet<TagMultiSelectResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => _TagMultiSelectSheet(
          tags: tags,
          initialSelectedIds: selectedIds,
          initialUntaggedOnly: untaggedOnly,
          allowCreate: allowCreate,
          allowUntagged: allowUntagged,
        ),
  );
}

class _TagMultiSelectSheet extends ConsumerStatefulWidget {
  const _TagMultiSelectSheet({
    required this.tags,
    required this.initialSelectedIds,
    required this.initialUntaggedOnly,
    required this.allowCreate,
    required this.allowUntagged,
  });

  final List<TagView> tags;
  final Set<String> initialSelectedIds;
  final bool initialUntaggedOnly;
  final bool allowCreate;
  final bool allowUntagged;

  @override
  ConsumerState<_TagMultiSelectSheet> createState() =>
      _TagMultiSelectSheetState();
}

class _TagMultiSelectSheetState extends ConsumerState<_TagMultiSelectSheet> {
  late final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedIds = widget.initialSelectedIds.intersection({
    for (final tag in widget.tags) tag.id,
  });
  late bool _untaggedOnly = widget.initialUntaggedOnly && widget.allowUntagged;
  List<TagView> _createdTags = const [];

  List<TagView> get _visibleTags => [...widget.tags, ..._createdTags];

  List<TagView> get _filteredTags {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _visibleTags;
    return [
      for (final tag in _visibleTags)
        if (tag.name.toLowerCase().contains(query)) tag,
    ];
  }

  String? get _creatableName {
    if (!widget.allowCreate) return null;
    final name = _searchController.text.trim();
    if (name.isEmpty) return null;
    if (_visibleTags.any((tag) => tag.name == name)) return null;
    return name;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final availableHeight =
        (mediaQuery.size.height - keyboardInset)
            .clamp(0.0, mediaQuery.size.height)
            .toDouble();
    final maxHeight =
        availableHeight * AppComponentTokens.selectionSheetMaxHeightFactor;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: AppMotion.durationFast,
      curve: Curves.easeOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
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
                        '选择标签',
                        style: context.appTextStyles.subsectionTitle,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _selectedIds.isEmpty && !_untaggedOnly
                              ? null
                              : () => setState(() {
                                _selectedIds.clear();
                                _untaggedOnly = false;
                              }),
                      child: const Text('清除'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  0,
                  AppSpacing.space16,
                  AppSpacing.space8,
                ),
                child: TagSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_creatableName case final name?)
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text('创建标签“$name”'),
                        subtitle: const Text('使用当前输入内容创建并选择'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        onTap: () => _createTag(name),
                      ),
                    if (_filteredTags.isEmpty &&
                        _creatableName == null &&
                        !widget.allowUntagged)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.space20),
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? (widget.allowCreate
                                  ? '还没有标签，输入名称创建一个吧'
                                  : '暂无可选标签')
                              : '没有匹配的标签',
                          style: context.appTextStyles.inputText,
                        ),
                      ),
                    if (widget.allowUntagged)
                      CheckboxListTile(
                        value: _untaggedOnly,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        title: Text(
                          '未打标签',
                          style: context.appTextStyles.formPlainValue,
                        ),
                        onChanged:
                            (_) => setState(() {
                              _untaggedOnly = !_untaggedOnly;
                              if (_untaggedOnly) _selectedIds.clear();
                            }),
                      ),
                    for (final tag in _filteredTags)
                      CheckboxListTile(
                        value: _selectedIds.contains(tag.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        title: Text(
                          tag.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.formPlainValue,
                        ),
                        onChanged: (_) => _toggle(tag.id),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSubmitButton(
                      label: '确定',
                      onPressed:
                          () => Navigator.of(context).pop(
                            TagMultiSelectResult(
                              selectedTagIds: Set.of(_selectedIds),
                              untaggedOnly: _untaggedOnly,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      _untaggedOnly = false;
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _createTag(String name) async {
    if (!widget.allowCreate) return;
    final service = ref.read(tagApplicationServiceProvider);
    final id = await service.createTag(name);
    if (!mounted) return;
    final alreadyListed = [
      ...widget.tags,
      ..._createdTags,
    ].any((tag) => tag.id == id);
    setState(() {
      if (!alreadyListed) {
        _createdTags = [
          ..._createdTags,
          TagView(id: id, name: name.trim(), sortOrder: 0, usageCount: 0),
        ];
      }
      _selectedIds.add(id);
    });
  }
}
