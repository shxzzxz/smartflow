import 'package:flutter/material.dart';

import '../../../../application/insurance/insurance_query_api.dart';
import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/spacing.dart';
import '../../../../design_system/widget/app_surface.dart';
import '../../presentation/insurance_presentation.dart';
import '../member_avatar_view.dart';

class InsuranceMemberHeader extends StatelessWidget {
  const InsuranceMemberHeader({required this.overview, super.key});

  final MemberCoverageOverview overview;

  @override
  Widget build(BuildContext context) {
    final person = overview.insuredPerson;
    final styles = context.appTextStyles;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemberAvatarView(preset: person.avatarPreset, size: 64),
            const SizedBox(width: AppSpacing.space14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.subsectionTitleStrong,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '${person.relationship.label} · '
                    '${insuranceCalendarDateLabel(person.birthDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.listSupporting,
                  ),
                  if (person.note case final note?) ...[
                    const SizedBox(height: AppSpacing.space6),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.listSupporting,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
