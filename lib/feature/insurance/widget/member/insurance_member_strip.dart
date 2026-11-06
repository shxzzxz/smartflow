import 'package:flutter/material.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/component.dart';
import '../../../../design_system/token/radius.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_surface.dart';
import '../member_avatar_view.dart';

class InsuranceMemberStrip extends StatelessWidget {
  const InsuranceMemberStrip({
    required this.members,
    required this.onMemberTap,
    super.key,
  });

  final List<InsuranceMemberListItem> members;
  final ValueChanged<InsuranceMemberListItem> onMemberTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space16,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < members.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.space12),
                _MemberItem(
                  member: members[index],
                  onTap: () => onMemberTap(members[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberItem extends StatelessWidget {
  const _MemberItem({required this.member, required this.onTap});

  final InsuranceMemberListItem member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return SizedBox(
      width: AppComponentTokens.memberStripItemWidth,
      child: InkWell(
        key: ValueKey('insurance-overview-member-${member.insuredPersonId}'),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
          child: Column(
            children: [
              MemberAvatarView(preset: member.avatarPreset, size: 56),
              const SizedBox(height: AppSpacing.space8),
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.listTitle,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '${member.commercialInsuranceCount} 份保单',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.listSupporting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
