import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/header.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';

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

class BookPickerButton extends StatefulWidget {
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
  final String bookId;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreateBook;
  final VoidCallback onManageBooks;
  final bool enabled;

  @override
  State<BookPickerButton> createState() => _BookPickerButtonState();
}

class _BookPickerButtonState extends State<BookPickerButton> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final book = widget.books
        .where((book) => book.id == widget.bookId)
        .firstOrNull;
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _menuController,
      useRootOverlay: true,
      crossAxisUnconstrained: false,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, AppSpacing.space4),
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        minimumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.menuMinWidth, 0),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.selectionMenuMaxWidth, double.infinity),
        ),
      ),
      menuChildren: [
        for (final option in widget.books)
          MenuItemButton(
            leadingIcon: const Icon(RemixIcons.book_open_line),
            trailingIcon: option.id == widget.bookId
                ? Icon(RemixIcons.check_line, color: colors.primary)
                : null,
            style: option.id == widget.bookId
                ? ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      colors.primary.withValues(
                        alpha: AppComponentTokens.selectedContainerOpacity,
                      ),
                    ),
                  )
                : null,
            onPressed: widget.enabled
                ? () {
                    _menuController.close();
                    widget.onChanged(option.id);
                  }
                : null,
            child: Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.listTitle,
            ),
          ),
        const Divider(height: AppSpacing.space16),
        MenuItemButton(
          leadingIcon: const Icon(RemixIcons.add_line),
          onPressed: widget.enabled
              ? () {
                  _menuController.close();
                  widget.onCreateBook();
                }
              : null,
          child: const Text('新建'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(RemixIcons.settings_3_line),
          onPressed: widget.enabled
              ? () {
                  _menuController.close();
                  widget.onManageBooks();
                }
              : null,
          child: const Text('管理'),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: '切换账本：${book?.name ?? '账本'}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppHeaderTokens.selectorMaxWidth,
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size(0, AppHeaderTokens.iconButtonSize),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppHeaderTokens.controlRadius,
                ),
              ),
            ),
            onPressed: widget.enabled
                ? (controller.isOpen ? controller.close : controller.open)
                : null,
            child: Text(
              book?.name ?? '账本',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
