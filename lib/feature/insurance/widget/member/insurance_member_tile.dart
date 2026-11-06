import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_surface.dart';
import '../member_avatar_view.dart';

class InsuranceMemberTile extends StatelessWidget {
  const InsuranceMemberTile({
    required this.member,
    required this.onTap,
    super.key,
    this.trailing,
  });

  final InsuranceMemberListItem member;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return AppSurface(
      border: true,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('insurance-member-${member.insuredPersonId}'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space14,
                  AppSpacing.space8,
                  AppSpacing.space14,
                ),
                child: Row(
                  children: [
                    MemberAvatarView(
                      preset: member.avatarPreset,
                      size: AppSpacing.space48,
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.listTitle,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Text(
                            '${member.relationship.label} · '
                            '${member.gender.label} · ${member.age} 岁',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.listSupporting,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Icon(
                      RemixIcons.arrow_right_s_line,
                      size: AppSpacing.space20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing case final trailing?) ...[
            trailing,
            const SizedBox(width: AppSpacing.space4),
          ],
        ],
      ),
    );
  }
}
