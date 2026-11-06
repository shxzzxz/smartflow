import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import 'member_avatar_view.dart';

Future<MemberAvatarPreset?> showMemberAvatarPickerSheet(
  BuildContext context, {
  required MemberAvatarPreset selected,
}) {
  return showModalBottomSheet<MemberAvatarPreset>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          AppSpacing.space4,
          AppSpacing.space20,
          AppSpacing.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择头像',
              textAlign: TextAlign.center,
              style: context.appTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.space20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.space16,
              runSpacing: AppSpacing.space16,
              children: [
                for (final preset in MemberAvatarPreset.values)
                  Semantics(
                    button: true,
                    selected: selected == preset,
                    label: '${preset.label}头像',
                    excludeSemantics: true,
                    child: InkResponse(
                      key: ValueKey('member-avatar-preset-${preset.name}'),
                      onTap: () => Navigator.of(context).pop(preset),
                      radius: AppSpacing.space32,
                      child: MemberAvatarView(
                        preset: preset,
                        size: 56,
                        selected: selected == preset,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
