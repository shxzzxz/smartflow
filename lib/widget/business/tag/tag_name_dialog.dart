import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';

/// 标签命名的文本输入对话框，新建与重命名共用；返回 null 表示取消。
Future<String?> promptTagName(
  BuildContext context, {
  required String title,
  String initialText = '',
}) {
  final controller = TextEditingController(text: initialText);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 20,
        style: context.appTextStyles.inputText,
        decoration: InputDecoration(
          hintText: '标签名称',
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
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
