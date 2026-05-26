import 'package:flutter/material.dart';

import '../token/spacing.dart';
import 'app_surface.dart';

class AppFormSection extends StatelessWidget {
  const AppFormSection({
    required this.children,
    super.key,
    this.spacing = AppSpacing.space16,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) SizedBox(height: spacing),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}
