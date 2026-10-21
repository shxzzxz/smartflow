import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';

/// 词表名称的文本输入对话框，新建与重命名共用；返回 null 表示取消。
Future<String?> promptName(
  BuildContext context, {
  required String title,
  required String hintText,
  String initialText = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _NameDialog(title: title, hintText: hintText, initialText: initialText),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hintText,
    required this.initialText,
  });

  final String title;
  final String hintText;
  final String initialText;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        style: context.appTextStyles.inputText,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: context.appTextStyles.inputText.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
