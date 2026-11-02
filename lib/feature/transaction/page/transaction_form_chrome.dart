part of 'transaction_form_page.dart';

class _TransactionFormStatusPage extends StatelessWidget {
  const _TransactionFormStatusPage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.editing,
    required this.onBack,
    required this.onDelete,
    required this.onModeChanged,
  });

  final TransactionFormMode mode;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback? onDelete;
  final ValueChanged<_TransactionModeTab> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space8,
        AppSpacing.space6,
        AppSpacing.space8,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(RemixIcons.arrow_left_s_line),
            tooltip: '返回',
            style: appHeaderIconButtonStyle,
          ),
          Expanded(
            child: editing
                ? Center(
                    child: Text(
                      '编辑${_modeTabFor(mode).label}',
                      style: context.appTextStyles.subsectionTitleStrong,
                    ),
                  )
                : _ModeTabs(mode: mode, onChanged: onModeChanged),
          ),
          if (editing)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(RemixIcons.delete_bin_line),
              tooltip: '删除',
              style: appHeaderIconButtonStyle,
            )
          else
            const SizedBox(width: AppHeaderTokens.iconButtonSize),
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final TransactionFormMode mode;
  final ValueChanged<_TransactionModeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final value in _TransactionModeTab.values)
                _ModeTabItem(
                  label: value.label,
                  selected: value == _modeTabFor(mode),
                  onTap: () => onChanged(value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabItem extends StatelessWidget {
  const _ModeTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppComponentTokens.controlMinHeight,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textStyles
                      .segmentedControlLabel(selected: selected)
                      .copyWith(
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.space6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: selected ? 40 : AppSpacing.space0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
