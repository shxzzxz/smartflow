import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';

class TransactionBatchTagActionSheet extends StatelessWidget {
  const TransactionBatchTagActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              0,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: Text('标签管理', style: context.appTextStyles.subsectionTitle),
          ),
          ListTile(
            leading: const Icon(RemixIcons.add_line),
            title: const Text('新增标签'),
            onTap: () =>
                Navigator.of(context).pop(TransactionTagBatchOperation.add),
          ),
          ListTile(
            leading: const Icon(RemixIcons.subtract_line),
            title: const Text('删除标签'),
            onTap: () =>
                Navigator.of(context).pop(TransactionTagBatchOperation.remove),
          ),
          ListTile(
            leading: const Icon(RemixIcons.delete_bin_line),
            title: const Text('清空标签'),
            onTap: () =>
                Navigator.of(context).pop(TransactionTagBatchOperation.clear),
          ),
        ],
      ),
    );
  }
}
