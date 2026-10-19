import 'package:flutter/material.dart';

import '../token/spacing.dart';
import 'app_list_divider.dart';
import 'app_surface.dart';

/// Groups row widgets inside one surface with shared inset dividers.
class AppListSection extends StatelessWidget {
  const AppListSection({
    required this.children,
    this.header,
    this.border = false,
    super.key,
  });

  final List<Widget> children;
  final Widget? header;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header case final header?) ...[
          header,
          const SizedBox(height: AppSpacing.space8),
        ],
        AppSurface(
          border: border,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const AppListDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
