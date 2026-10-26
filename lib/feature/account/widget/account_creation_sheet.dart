import 'package:flutter/material.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_grouped_choice_grid.dart';
import '../../../widget/business/icon/business_icon.dart';
import '../presentation/account_creation_presets.dart';

Future<AccountCreationPreset?> showAccountCreationSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<AccountCreationPreset>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _AccountCreationSheet(),
  );
}

class _AccountCreationSheet extends StatelessWidget {
  const _AccountCreationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedChoiceGrid<AccountCreationPreset>(
              groups: [
                for (final group in accountCreationGroups)
                  AppChoiceGridGroup(
                    id: group.id,
                    label: group.label,
                    items: [
                      for (final preset in group.presets)
                        AppChoiceGridItem(
                          id: preset.id,
                          value: preset,
                          label: preset.label,
                          iconBuilder: (context, size) => BusinessIcon(
                            iconKey: preset.iconKey,
                            size: size,
                            usage: BusinessIconUsage.account,
                          ),
                        ),
                    ],
                  ),
              ],
              onSelected: (item) => Navigator.of(context).pop(item.value),
            ),
          ],
        ),
      ),
    );
  }
}
