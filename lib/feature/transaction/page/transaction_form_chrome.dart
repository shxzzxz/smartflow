part of 'transaction_form_page.dart';

class _TransactionFormStatusPage extends StatelessWidget {
  const _TransactionFormStatusPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(child: Center(child: child)),
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
    final actions = [
      if (editing)
        AppHeaderIconButton(
          onPressed: onDelete,
          icon: RemixIcons.delete_bin_line,
          tooltip: '删除',
        ),
    ];
    if (editing) {
      return AppPageHeader(
        title: '编辑${_modeTabFor(mode).label}',
        onBack: onBack,
        actions: actions,
      );
    }
    return AppPageHeader.custom(
      onBack: onBack,
      titleContent: _ModeTabs(mode: mode, onChanged: onModeChanged),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final TransactionFormMode mode;
  final ValueChanged<_TransactionModeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AppSlidingSegmentedControl<_TransactionModeTab>(
        variant: AppSegmentedControlVariant.header,
        segments: [
          for (final tab in _TransactionModeTab.values)
            AppSegment(value: tab, label: tab.label),
        ],
        selected: _modeTabFor(mode),
        onChanged: onChanged,
      ),
    );
  }
}
