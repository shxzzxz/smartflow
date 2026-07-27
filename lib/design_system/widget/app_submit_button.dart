import 'package:flutter/material.dart';

import '../token/spacing.dart';

enum AppSubmitButtonTone { primary, danger }

class AppSubmitButton extends StatelessWidget {
  const AppSubmitButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
    this.tone = AppSubmitButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppSubmitButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSpacing.space48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: switch (tone) {
          AppSubmitButtonTone.primary => null,
          AppSubmitButtonTone.danger => FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
        },
        child:
            loading
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(label),
      ),
    );
  }
}
