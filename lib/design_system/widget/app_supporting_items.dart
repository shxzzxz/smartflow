import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/spacing.dart';
import 'app_status_badge.dart';

@immutable
class AppSupportingText {
  const AppSupportingText(this.text, {this.tone = AppStatusTone.neutral});

  final String text;
  final AppStatusTone tone;
}

/// Wraps compact supporting labels under a primary list title.
class AppSupportingItems extends StatelessWidget {
  const AppSupportingItems({required this.items, super.key});

  final List<AppSupportingText> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space8,
      runSpacing: AppSpacing.space2,
      children: [
        for (final item in items)
          Text(
            item.text,
            style: context.appTextStyles.listSupporting.copyWith(
              color: appStatusToneColor(context, item.tone),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
