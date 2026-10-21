import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/spacing.dart';
import '../tag/tag_search_field.dart';

/// 单值对手方选择结果；[counterparty] 为 null 表示明确清除。
class CounterpartySelection {
  const CounterpartySelection(this.counterparty);

  final CounterpartyView? counterparty;

  String? get counterpartyId => counterparty?.id;
}

Future<CounterpartySelection?> showCounterpartySingleSelectSheet({
  required BuildContext context,
  required List<CounterpartyView> counterparties,
  required String? selectedId,
}) {
  return showModalBottomSheet<CounterpartySelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CounterpartySingleSelectSheet(
      counterparties: counterparties,
      initialSelectedId: selectedId,
    ),
  );
}

class _CounterpartySingleSelectSheet extends ConsumerStatefulWidget {
  const _CounterpartySingleSelectSheet({
    required this.counterparties,
    required this.initialSelectedId,
  });

  final List<CounterpartyView> counterparties;
  final String? initialSelectedId;

  @override
  ConsumerState<_CounterpartySingleSelectSheet> createState() =>
      _CounterpartySingleSelectSheetState();
}

class _CounterpartySingleSelectSheetState
    extends ConsumerState<_CounterpartySingleSelectSheet> {
  late final TextEditingController _searchController = TextEditingController();
  late String? _selectedId = widget.initialSelectedId;
  List<CounterpartyView> _createdCounterparties = const [];

  List<CounterpartyView> get _visibleCounterparties => [
    ...widget.counterparties,
    ..._createdCounterparties,
  ];

  List<CounterpartyView> get _filteredCounterparties {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _visibleCounterparties;
    return [
      for (final counterparty in _visibleCounterparties)
        if (counterparty.name.toLowerCase().contains(query)) counterparty,
    ];
  }

  String? get _creatableName {
    final name = _searchController.text.trim();
    if (name.isEmpty) return null;
    if (_visibleCounterparties.any(
      (counterparty) => counterparty.name == name,
    )) {
      return null;
    }
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
    final availableHeight = (mediaQuery.size.height - keyboardInset)
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
                        '选择对手方',
                        style: context.appTextStyles.subsectionTitle,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const CounterpartySelection(null)),
                      child: const Text('不设置'),
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
                  key: const ValueKey('counterparty-search-field'),
                  controller: _searchController,
                  hintText: '搜索对手方',
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
                        title: Text('创建对手方“$name”'),
                        subtitle: const Text('使用当前输入内容创建并选择'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        onTap: () => _createCounterparty(name),
                      ),
                    if (_filteredCounterparties.isEmpty &&
                        _creatableName == null)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.space20),
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? '还没有对手方，输入名称创建一个吧'
                              : '没有匹配的对手方',
                          style: context.appTextStyles.inputText,
                        ),
                      ),
                    for (final counterparty in _filteredCounterparties)
                      ListTile(
                        leading: const Icon(Icons.account_circle_outlined),
                        title: Text(
                          counterparty.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.formValue,
                        ),
                        trailing: counterparty.id == _selectedId
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(CounterpartySelection(counterparty)),
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

  Future<void> _createCounterparty(String name) async {
    final service = ref.read(counterpartyApplicationServiceProvider);
    final id = await service.createCounterparty(name);
    if (!mounted) return;
    final alreadyListed = [
      ...widget.counterparties,
      ..._createdCounterparties,
    ].any((counterparty) => counterparty.id == id);
    if (!alreadyListed) {
      setState(() {
        _selectedId = id;
        _createdCounterparties = [
          ..._createdCounterparties,
          CounterpartyView(id: id, name: name.trim()),
        ];
      });
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(CounterpartySelection(CounterpartyView(id: id, name: name.trim())));
  }
}
