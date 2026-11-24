import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/shared/name_dialog.dart';
import '../../shared/provider/book_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';

class BooksPage extends ConsumerStatefulWidget {
  const BooksPage({super.key});

  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  void _showOutcome<T>(UiActionOutcome<T> outcome) {
    if (outcome case UiActionFailure<T>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editName([Book? book]) async {
    final name = await promptName(
      context,
      title: book == null ? '新增账本' : '重命名账本',
      hintText: '账本名称',
      initialText: book?.name ?? '',
    );
    if (name == null || !mounted) return;
    final vm = ref.read(bookSelectionViewModelProvider.notifier);
    if (book == null) {
      final outcome = await vm.createBook(name);
      if (mounted) _showOutcome(outcome);
    } else {
      final outcome = await vm.renameBook(book, name);
      if (mounted) _showOutcome(outcome);
    }
  }

  Future<void> _delete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账本'),
        content: Text('确定删除“${book.name}”吗？已被交易使用的账本无法删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await ref
        .read(bookSelectionViewModelProvider.notifier)
        .deleteBook(book);
    if (mounted) {
      _showOutcome(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(bookSelectionViewModelProvider);
    final submitting = selection.value?.submitting ?? false;
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '账本管理',
              onBack: () => context.pop(),
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新增账本',
                  onPressed: submitting ? null : () => _editName(),
                ),
              ],
            ),
            Expanded(
              child: selection.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(bookSelectionViewModelProvider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (value) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space20,
                    AppSpacing.space8,
                    AppSpacing.space20,
                    AppSpacing.space48,
                  ),
                  itemCount: value.books.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.space12),
                  itemBuilder: (context, index) {
                    final book = value.books[index];
                    return _BookCard(
                      key: ValueKey(book.id),
                      book: book,
                      isCurrent: book.id == value.currentBook.id,
                      enabled: !submitting,
                      onRename: () => _editName(book),
                      onDelete: () => _delete(book),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BookAction { rename, delete }

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.isCurrent,
    required this.enabled,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final Book book;
  final bool isCurrent;
  final bool enabled;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: InkWell(
        onTap: enabled ? onRename : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space12,
            AppSpacing.space4,
            AppSpacing.space12,
          ),
          child: Row(
            children: [
              Container(
                width: AppSpacing.space32,
                height: AppSpacing.space32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: AppComponentTokens.selectedContainerOpacity,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                ),
                child: Icon(
                  RemixIcons.book_open_line,
                  size: AppSpacing.space20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.listTitle,
                    ),
                    if (book.isBuiltin || isCurrent) ...[
                      const SizedBox(height: AppSpacing.space4),
                      Wrap(
                        spacing: AppSpacing.space6,
                        runSpacing: AppSpacing.space4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (book.isBuiltin)
                            Text(
                              '内置账本 · 不可删除',
                              style: context.appTextStyles.listSupporting,
                            ),
                          if (isCurrent)
                            const AppStatusBadge(
                              presentation: AppStatusBadgePresentation(
                                label: '当前账本',
                                tone: AppStatusTone.primary,
                              ),
                              size: AppStatusBadgeSize.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_BookAction>(
                enabled: enabled,
                tooltip: '更多操作',
                icon: Icon(
                  RemixIcons.more_2_line,
                  size: AppSpacing.space20,
                  color: colors.onSurfaceVariant,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _BookAction.rename:
                      onRename();
                    case _BookAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _BookAction.rename,
                    child: Text('重命名'),
                  ),
                  if (!book.isBuiltin)
                    const PopupMenuItem(
                      value: _BookAction.delete,
                      child: Text('删除'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
