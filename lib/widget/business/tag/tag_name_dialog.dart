import 'package:flutter/material.dart';

/// 标签命名的文本输入对话框，新建与重命名共用；返回 null 表示取消。
Future<String?> promptTagName(
  BuildContext context, {
  required String title,
  String initialText = '',
}) {
  final controller = TextEditingController(text: initialText);
  return showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '标签名称'),
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
