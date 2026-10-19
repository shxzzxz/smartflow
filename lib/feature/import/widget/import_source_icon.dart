import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/token/spacing.dart';

import '../presentation/import_presentation.dart';

class ImportSourceIcon extends StatelessWidget {
  const ImportSourceIcon({
    required this.source,
    super.key,
    this.size = AppSpacing.space40,
  });

  final ImportEntrySource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = switch (source) {
      ImportEntrySource.yimu => (
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      ),
      ImportEntrySource.unionPay => (
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
      ),
      ImportEntrySource.generic => (
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
      ),
    };
    final icon = switch (source) {
      ImportEntrySource.yimu => Icons.energy_savings_leaf_rounded,
      ImportEntrySource.unionPay => RemixIcons.bank_card_line,
      ImportEntrySource.generic => RemixIcons.file_excel_2_line,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: palette.foreground),
    );
  }
}
