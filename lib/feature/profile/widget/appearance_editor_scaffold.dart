import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../shared/view_model/ui_action_outcome.dart';

/// 外观草稿编辑的页面外壳，统一保存反馈和未保存退出确认。
class AppearanceEditorScaffold extends StatefulWidget {
  const AppearanceEditorScaffold({
    required this.title,
    required this.hasChanges,
    required this.submitting,
    required this.onRestoreDefaults,
    required this.onSave,
    required this.onDiscardChanges,
    required this.child,
    super.key,
  });

  final String title;
  final bool hasChanges;
  final bool submitting;
  final VoidCallback? onRestoreDefaults;
  final Future<UiActionOutcome<void>> Function()? onSave;
  final VoidCallback onDiscardChanges;
  final Widget child;

  @override
  State<AppearanceEditorScaffold> createState() =>
      _AppearanceEditorScaffoldState();
}

class _AppearanceEditorScaffoldState extends State<AppearanceEditorScaffold> {
  bool _confirmingExit = false;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.hasChanges && !widget.submitting,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _requestExit();
    },
    child: AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: widget.title,
              onBack: _requestExit,
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.refresh_line,
                  tooltip: '恢复默认',
                  onPressed: widget.submitting
                      ? null
                      : widget.onRestoreDefaults,
                ),
                AppHeaderTextButton(
                  label: widget.submitting ? '保存中' : '保存',
                  onPressed:
                      !widget.submitting &&
                          widget.hasChanges &&
                          widget.onSave != null
                      ? _save
                      : null,
                ),
              ],
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    ),
  );

  Future<void> _save() async {
    final outcome = await widget.onSave!();
    if (!mounted) return;
    final message = switch (outcome) {
      UiActionSuccess() => '${widget.title}已保存',
      UiActionFailure(:final error) => error.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestExit() async {
    if (widget.submitting || _confirmingExit) return;
    if (widget.hasChanges) {
      _confirmingExit = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (discard != true || !mounted) return;
      widget.onDiscardChanges();
    }
    if (mounted) Navigator.of(context).pop();
  }
}
