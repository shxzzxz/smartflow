import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../icon/business_icon.dart';

Future<Set<String>?> showAccountMultiSelectSheet({
  required BuildContext context,
  required List<Account> accounts,
  required Set<String> selectedIds,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AccountMultiSelectSheet(
      accounts: accounts,
      initialSelectedIds: selectedIds,
    ),
  );
}

class _AccountMultiSelectSheet extends StatefulWidget {
  const _AccountMultiSelectSheet({
    required this.accounts,
    required this.initialSelectedIds,
  });

  final List<Account> accounts;
  final Set<String> initialSelectedIds;

  @override
  State<_AccountMultiSelectSheet> createState() =>
      _AccountMultiSelectSheetState();
}

class _AccountMultiSelectSheetState extends State<_AccountMultiSelectSheet> {
  late final Set<String> _allIds = {
    for (final account in widget.accounts) account.id,
  };
  late final Set<String> _selectedIds = widget.initialSelectedIds.intersection(
    _allIds,
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
                      '选择账户',
                      style: context.appTextStyles.subsectionTitle,
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedIds.length == _allIds.length
                        ? null
                        : () => setState(() {
                            _selectedIds
                              ..clear()
                              ..addAll(_allIds);
                          }),
                    child: const Text('全部'),
                  ),
                  TextButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => setState(_selectedIds.clear),
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.accounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space20),
                      child: Text(
                        '暂无可选账户',
                        style: context.appTextStyles.inputText,
                      ),
                    ),
                  for (final account in widget.accounts)
                    CheckboxListTile(
                      value: _selectedIds.contains(account.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                      ),
                      title: Row(
                        children: [
                          BusinessIcon(
                            iconKey: account.iconKey,
                            size: AppSpacing.space20,
                            usage: BusinessIconUsage.account,
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          Expanded(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextStyles.formValue,
                            ),
                          ),
                        ],
                      ),
                      onChanged: (_) => _toggle(account.id),
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
              child: AppSubmitButton(
                label: '确定',
                onPressed: () =>
                    Navigator.of(context).pop(Set.of(_selectedIds)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }
}
