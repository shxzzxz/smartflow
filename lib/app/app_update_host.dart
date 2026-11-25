import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/update/app_update_info.dart';
import '../design_system/theme/app_text_styles.dart';
import 'app_update_providers.dart';

class AppUpdateHost extends ConsumerStatefulWidget {
  const AppUpdateHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends ConsumerState<AppUpdateHost>
    with WidgetsBindingObserver {
  bool _isForeground = true;
  bool _isDialogOpen = false;
  bool _handlingScheduled = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(
        appUpdateControllerProvider,
        (previous, next) => _scheduleHandling(),
        fireImmediately: true,
      );
      unawaited(
        ref.read(appUpdateControllerProvider.notifier).checkAtStartup(),
      );
    });
  }

  void _scheduleHandling() {
    if (_handlingScheduled) return;
    _handlingScheduled = true;
    scheduleMicrotask(() {
      _handlingScheduled = false;
      if (mounted && _isForeground) _handleUpdate();
    });
  }

  void _handleUpdate() {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final state = ref.read(appUpdateControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(navigatorContext);
    if (state.message != null && messenger != null) {
      final message = controller.takeMessage();
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }
    if (state.pendingUpdate != null && !_isDialogOpen) {
      _isDialogOpen = true;
      final update = controller.takeUpdatePrompt()!;
      unawaited(_showUpdatePrompt(navigatorContext, update));
    }
    if (state.downloadStatus == AppUpdateDownloadStatus.readyToInstall) {
      unawaited(controller.installDownloadedUpdate());
    }
  }

  Future<void> _showUpdatePrompt(
    BuildContext navigatorContext,
    AppUpdateInfo update,
  ) async {
    try {
      final accepted = await showDialog<bool>(
        context: navigatorContext,
        barrierDismissible: !update.required,
        builder: (context) => _AppUpdateDialog(update: update),
      );
      if (mounted && accepted == true) {
        unawaited(
          ref.read(appUpdateControllerProvider.notifier).downloadUpdate(update),
        );
      }
    } finally {
      _isDialogOpen = false;
      if (mounted) _scheduleHandling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) _scheduleHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({required this.update});

  final AppUpdateInfo update;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !update.required,
      child: AlertDialog(
        title: Text('发现新版本 ${update.versionName}'),
        content: SingleChildScrollView(
          child: Text(
            update.notes.isEmpty ? '有新的版本可用。' : update.notes,
            style: context.appTextStyles.detailValue,
          ),
        ),
        actions: [
          if (!update.required)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
