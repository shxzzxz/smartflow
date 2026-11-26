import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_header_select_button.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_select.dart';

Future<String?> pickBook(
  BuildContext context, {
  required List<Book> books,
  required String selectedBookId,
}) async {
  Widget buildPicker(BuildContext pickerContext) => _BookPickerList(
    books: books,
    selectedBookId: selectedBookId,
    onSelected: (id) => Navigator.of(pickerContext).pop(id),
  );

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(child: buildPicker(sheetContext)),
  );
}

class _BookPickerList extends StatelessWidget {
  const _BookPickerList({
    required this.books,
    required this.selectedBookId,
    required this.onSelected,
  });

  final List<Book> books;
  final String selectedBookId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height *
            AppComponentTokens.selectionSheetMaxHeightFactor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Text(
              '选择账本',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                0,
                AppSpacing.space8,
                AppSpacing.space8,
              ),
              itemCount: books.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.space4),
              itemBuilder: (context, index) {
                final book = books[index];
                final selected = book.id == selectedBookId;
                return ListTile(
                  leading: const Icon(RemixIcons.book_open_line),
                  title: Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.listTitle,
                  ),
                  selected: selected,
                  selectedTileColor: colors.primary.withValues(
                    alpha: AppComponentTokens.selectedContainerOpacity,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                  ),
                  trailing: selected ? const Icon(RemixIcons.check_line) : null,
                  onTap: () => onSelected(book.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookPickerButton extends StatelessWidget {
  const BookPickerButton({
    required this.books,
    required this.bookId,
    required this.onChanged,
    required this.onCreateBook,
    required this.onManageBooks,
    this.enabled = true,
    super.key,
  });

  final List<Book> books;
  final String? bookId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateBook;
  final VoidCallback onManageBooks;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final book = books.where((book) => book.id == bookId).firstOrNull;
    final name = bookId == null ? '全部账本' : book?.name ?? '账本';
    return AppHeaderSelectButton<String?>(
      label: name,
      tooltip: '切换账本：$name',
      value: bookId,
      onChanged: enabled ? onChanged : null,
      options: [
        const AppSelectOption(
          value: null,
          label: '全部账本',
          icon: RemixIcons.book_open_line,
        ),
        for (final book in books)
          AppSelectOption(
            value: book.id,
            label: book.name,
            icon: RemixIcons.book_open_line,
          ),
      ],
      actions: [
        AppPopupMenuAction(
          label: '新建',
          icon: RemixIcons.add_line,
          onPressed: enabled ? onCreateBook : null,
        ),
        AppPopupMenuAction(
          label: '管理',
          icon: RemixIcons.settings_3_line,
          onPressed: enabled ? onManageBooks : null,
        ),
      ],
    );
  }
}
