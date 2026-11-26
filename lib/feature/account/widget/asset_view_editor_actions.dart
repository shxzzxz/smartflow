import 'package:flutter/material.dart';
import '../../shared/view_model/ui_action_outcome.dart';

Future<bool> confirmDiscardAssetViewChanges(BuildContext context) async =>
    await showDialog<bool>(
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
    ) ??
    false;

void showAssetViewFailure<T>(BuildContext context, UiActionOutcome<T> outcome) {
  if (outcome case UiActionFailure<T>(:final error)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}
