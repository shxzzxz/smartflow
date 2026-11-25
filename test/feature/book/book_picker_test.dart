// 测试替身只在根 ProviderScope 中覆盖。
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/widget/app_month_picker.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/feature/book/page/books_page.dart';
import 'package:smartflow/feature/book/widget/book_picker.dart';
import 'package:smartflow/feature/home/page/home_page.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/book_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  for (final failure in ['books', 'settings', 'both']) {
    testWidgets('management retries a failed $failure source', (tester) async {
      var bookReads = 0;
      final settingsStore = _RetrySettingsStore(
        failFirstRead: failure != 'books',
      );
      final daily = Book(id: Book.dailyId, name: Book.dailyName);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appSettingsStoreProvider.overrideWithValue(settingsStore),
            bookListProvider.overrideWith((ref) {
              bookReads++;
              return failure != 'settings' && bookReads == 1
                  ? Stream<List<Book>>.error(Exception('book read failed'))
                  : Stream.value([daily]);
            }),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const BooksPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加载失败，点击重试'), findsOneWidget);

      await tester.tap(find.text('加载失败，点击重试'));
      await tester.pumpAndSettle();

      expect(bookReads, failure == 'settings' ? 1 : 2);
      expect(settingsStore.reads, failure == 'books' ? 1 : 2);
      expect(find.text('加载失败，点击重试'), findsNothing);
      expect(find.text(Book.dailyName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('anchored selection reports a choice without a provider scope', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BookPickerButton(
              books: _bookOptions(),
              bookId: 'a',
              onChanged: (id) => picked = id,
              onCreateBook: () {},
              onManageBooks: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final trigger = tester.getRect(find.byType(BookPickerButton));
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    final firstOption = tester.getRect(find.byType(MenuItemButton).first);
    expect(
      firstOption.width,
      lessThanOrEqualTo(AppComponentTokens.selectionMenuMaxWidth),
    );
    final selectedMark = tester.getRect(find.byIcon(RemixIcons.check_line));
    expect(
      selectedMark.right,
      lessThanOrEqualTo(
        firstOption.left + AppComponentTokens.selectionMenuMaxWidth,
      ),
    );
    expect(firstOption.left, moreOrLessEquals(trigger.left));
    expect(firstOption.top, greaterThanOrEqualTo(trigger.bottom));
    expect(firstOption.top, lessThan(trigger.bottom + 16));
    final lastOption = tester.getRect(
      find.ancestor(of: find.text('B'), matching: find.byType(MenuItemButton)),
    );
    final create = tester.getRect(
      find.ancestor(of: find.text('新建'), matching: find.byType(MenuItemButton)),
    );
    final manage = tester.getRect(
      find.ancestor(of: find.text('管理'), matching: find.byType(MenuItemButton)),
    );
    expect(create.top, greaterThan(lastOption.bottom));
    expect(manage.top, greaterThanOrEqualTo(create.bottom));
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
    expect(find.text('新建'), findsNothing);
    expect(find.text('管理'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled selection does not open or invoke actions', (
    tester,
  ) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookPickerButton(
            books: _bookOptions(),
            bookId: 'a',
            enabled: false,
            onChanged: (_) => invoked = true,
            onCreateBook: () => invoked = true,
            onManageBooks: () => invoked = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    expect(find.text('新建'), findsNothing);
    expect(find.text('管理'), findsNothing);
    expect(invoked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home menu creates and selects a book after cancelling once', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    expect(find.text('新建账本'), findsOneWidget);
    expect(find.text('管理'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    expect(
      container
          .read(bookSelectionViewModelProvider)
          .requireValue
          .currentBook
          .id,
      'a',
    );

    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(bookSelectionViewModelProvider)
          .requireValue
          .currentBook
          .id,
      'new',
    );
    expect(
      container
          .read(bookSelectionViewModelProvider)
          .requireValue
          .books
          .any((book) => book.id == 'new' && book.name == '旅行'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home menu opens management and closes before navigation', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/books', builder: (context, state) => const BooksPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_homeApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    expect(find.byType(BooksPage), findsOneWidget);
    expect(find.text('账本管理'), findsOneWidget);
    expect(find.text('管理'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home selects all books and switches back to daily', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部账本'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    final selection = container
        .read(bookSelectionViewModelProvider)
        .requireValue;
    expect(selection.currentBook.id, Book.dailyId);
    expect(selection.showAllBooks, isTrue);
    expect(find.byTooltip('切换账本：全部账本'), findsOneWidget);
    expect(find.text('全部账本'), findsOneWidget);
    expect(find.text('新建'), findsNothing);

    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    final allBooksOption = find.ancestor(
      of: find.text('全部账本'),
      matching: find.byType(MenuItemButton),
    );
    expect(
      find.descendant(
        of: allBooksOption,
        matching: find.byIcon(RemixIcons.check_line),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(Book.dailyName));
    await tester.pumpAndSettle();
    final daily = container.read(bookSelectionViewModelProvider).requireValue;
    expect(daily.showAllBooks, isFalse);
    expect(daily.queryBookId, Book.dailyId);
    expect(find.byTooltip('切换账本：${Book.dailyName}'), findsOneWidget);
    expect(find.text('全部账本'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'management creates a book and offers no delete action for daily',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookSelectionViewModelProvider.overrideWith(_Books.new)],
          child: MaterialApp(theme: AppTheme.light(), home: const BooksPage()),
        ),
      );
      await tester.pumpAndSettle();
      final dailyCard = find.ancestor(
        of: find.text(Book.dailyName),
        matching: find.byType(AppSurface),
      );
      expect(dailyCard, findsOneWidget);
      expect(find.text('当前账本'), findsOneWidget);
      await tester.tap(
        find.descendant(of: dailyCard, matching: find.byTooltip('更多操作')),
      );
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新增账本'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '旅行');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('旅行'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('旅行'), matching: find.byType(AppSurface)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home book control stays on the left with narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookSelectionViewModelProvider.overrideWith(_Books.new)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Column(
                children: [
                  AppPageHeader.custom(
                    showBackButton: false,
                    singleRow: true,
                    leading: BookPickerButton(
                      books: _bookOptions(),
                      bookId: 'a',
                      onChanged: (_) {},
                      onCreateBook: () {},
                      onManageBooks: () {},
                    ),
                    titleContent: AppMonthSelector(
                      visibleMonth: DateTime(2026, 1),
                      onPreviousMonth: () {},
                      onMonthPressed: () {},
                      onNextMonth: () {},
                    ),
                    actions: [
                      AppHeaderIconButton(
                        icon: RemixIcons.filter_line,
                        tooltip: '筛选',
                        onPressed: () {},
                      ),
                      AppHeaderIconButton(
                        icon: RemixIcons.settings_3_line,
                        tooltip: '设置',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bookBounds = tester.getRect(find.byType(BookPickerButton));
    final headerBounds = tester.getRect(find.byType(AppPageHeader));
    final monthBounds = tester.getRect(find.byType(AppMonthSelector));
    expect(monthBounds.center.dy, moreOrLessEquals(bookBounds.center.dy));
    expect(bookBounds.center.dx, lessThan(headerBounds.center.dx));
    expect(headerBounds.contains(bookBounds.topLeft), isTrue);
    expect(headerBounds.contains(bookBounds.bottomRight), isTrue);
    await tester.tap(find.byType(BookPickerButton));
    await tester.pumpAndSettle();
    final manageBounds = tester.getRect(
      find.ancestor(of: find.text('管理'), matching: find.byType(MenuItemButton)),
    );
    expect(manageBounds.left, greaterThanOrEqualTo(0));
    expect(manageBounds.right, lessThanOrEqualTo(320));
    expect(manageBounds.bottom, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });
}

Widget _homeApp({GoRouter? router}) {
  return ProviderScope(
    overrides: [
      bookSelectionViewModelProvider.overrideWith(_Books.new),
      appSettingsStoreProvider.overrideWithValue(
        _RetrySettingsStore(failFirstRead: false),
      ),
      currentDateTimeProvider.overrideWith((ref) => DateTime(2026, 1, 15)),
      homeFilterOptionsProvider.overrideWith(
        (ref) => const HomeFilterOptionsState.loaded(
          expenseTree: [],
          incomeTree: [],
          accounts: [],
        ),
      ),
      homeContentProvider(
        DateTime(2026, 1),
      ).overrideWith((ref) => const HomeContentState.error(message: '首页内容')),
    ],
    child: router == null
        ? MaterialApp(theme: AppTheme.light(), home: const HomePage())
        : MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

List<Book> _bookOptions() => [
  Book(id: Book.dailyId, name: Book.dailyName),
  Book(id: 'a', name: '一个用于验证窄屏显示的长账本名称'),
  Book(id: 'b', name: 'B'),
];

class _Books extends BookSelectionViewModel {
  @override
  AsyncValue<BookSelectionState> build() {
    final books = _bookOptions();
    return AsyncData(BookSelectionState(books: books, currentBook: books[1]));
  }

  @override
  Future<UiActionOutcome<void>> selectBook(String? id) async {
    final current = state.requireValue;
    state = AsyncData(
      BookSelectionState(
        books: current.books,
        currentBook: current.books.firstWhere(
          (book) => book.id == (id ?? Book.dailyId),
        ),
        showAllBooks: id == null,
      ),
    );
    return const UiActionOutcome.success(null);
  }

  @override
  Future<UiActionOutcome<Book>> createBook(String name) async {
    final current = state.requireValue;
    final book = Book(id: 'new', name: name);
    state = AsyncData(
      BookSelectionState(
        books: [...current.books, book],
        currentBook: current.currentBook,
        showAllBooks: current.showAllBooks,
      ),
    );
    return UiActionOutcome.success(book);
  }
}

class _RetrySettingsStore implements AppSettingsStore {
  _RetrySettingsStore({required this.failFirstRead});

  final bool failFirstRead;
  int reads = 0;

  @override
  Future<AppSettings> read() async {
    reads++;
    if (failFirstRead && reads == 1) throw Exception('settings read failed');
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {}
}
