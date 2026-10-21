import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../tag/tag_search_field.dart';

enum TransactionReferenceOperation { merge, migrate }

extension TransactionReferenceOperationLabel on TransactionReferenceOperation {
  String get label => switch (this) {
    TransactionReferenceOperation.merge => '合并',
    TransactionReferenceOperation.migrate => '迁移',
  };
}

class TransactionReferenceTarget {
  const TransactionReferenceTarget({
    required this.id,
    required this.name,
    required this.usageCount,
  });

  final String id;
  final String name;
  final int usageCount;
}

/// 为标签或对手方选择交易引用的目标词表项。
Future<TransactionReferenceTarget?> showTransactionReferenceTargetSheet(
  BuildContext context, {
  required String sourceDescription,
  required String entityLabel,
  required TransactionReferenceOperation operation,
  required List<TransactionReferenceTarget> candidates,
}) {
  return showModalBottomSheet<TransactionReferenceTarget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.72,
      child: _TargetPickerSheet(
        sourceDescription: sourceDescription,
        entityLabel: entityLabel,
        operation: operation,
        candidates: candidates,
      ),
    ),
  );
}

class _TargetPickerSheet extends StatefulWidget {
  const _TargetPickerSheet({
    required this.sourceDescription,
    required this.entityLabel,
    required this.operation,
    required this.candidates,
  });

  final String sourceDescription;
  final String entityLabel;
  final TransactionReferenceOperation operation;
  final List<TransactionReferenceTarget> candidates;

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = [
      for (final target in widget.candidates)
        if (normalizedQuery.isEmpty ||
            target.name.toLowerCase().contains(normalizedQuery))
          target,
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space20,
              0,
              AppSpacing.space20,
              AppSpacing.space12,
            ),
            child: Text(
              '${widget.operation.label}${widget.sourceDescription}到',
              style: context.appTextStyles.subsectionTitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
            child: TagSearchField(
              controller: _searchController,
              hintText: '搜索目标${widget.entityLabel}',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '没有匹配的${widget.entityLabel}',
                      style: context.appTextStyles.inputText,
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final target = filtered[index];
                      return ListTile(
                        title: Text(target.name),
                        subtitle: Text('${target.usageCount} 笔交易'),
                        onTap: () => Navigator.of(context).pop(target),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
