import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Text(
            '$title功能正在建设中',
            style: context.appTextStyles.formPlainValue.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
