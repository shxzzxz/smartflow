import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'category_form_view_model.g.dart';

final _logger = Logger('feature.category.form');

@riverpod
class CategoryFormViewModel extends _$CategoryFormViewModel {
  CategoryFormState? _initializedState;
  String? _categoryId;

  @override
  AsyncValue<CategoryFormState?> build({
    String? categoryId,
    AccountType initialType = AccountType.expense,
    String? initialParentId,
  }) {
    _categoryId = categoryId;
    final expenseTreeAsync = ref.watch(
      categoryTreeProvider(AccountType.expense),
    );
    final incomeTreeAsync = ref.watch(categoryTreeProvider(AccountType.income));
    final accountAsync =
        categoryId == null ? null : ref.watch(accountsByIdProvider);
    if (_initializedState != null) {
      final next = _initializedState!.copyWith(
        expenseTree: expenseTreeAsync.value,
        incomeTree: incomeTreeAsync.value,
      );
      _initializedState = next;
      return AsyncValue.data(next);
    }
    if (categoryId == null) {
      return AsyncValue.data(
        _initializedState ??= CategoryFormState.initial(
          type: initialType,
          parentId: initialParentId,
          expenseTree: expenseTreeAsync.value ?? const <CategoryNode>[],
          incomeTree: incomeTreeAsync.value ?? const <CategoryNode>[],
        ),
      );
    }

    return accountAsync!.whenData((categories) {
      final category = categories[categoryId];
      if (category == null || !category.type.isCategory) return null;
      return _initializedState ??= CategoryFormState.fromCategory(
        category,
        expenseTree: expenseTreeAsync.value ?? const <CategoryNode>[],
        incomeTree: incomeTreeAsync.value ?? const <CategoryNode>[],
      );
    });
  }

  void setType(AccountType value) {
    _update((current) {
      if (current.type == value) return current;
      return current.copyWith(
        type: value,
        parentId: null,
        iconKey: defaultCategoryIconKey(value),
      );
    });
  }

  void setParentId(String? value) {
    _update((current) => current.copyWith(parentId: value));
  }

  void setIconKey(String value) {
    _update(
      (current) =>
          current.iconKey == value ? current : current.copyWith(iconKey: value),
    );
  }

  Future<SubmitOutcome> submit({
    required String nameText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('分类表单尚未加载');
    final name = trimToNull(nameText);
    if (name == null) {
      return _invalidCommand('请输入分类名称');
    }
    final note = trimToNull(noteText);

    _update((current) => current.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Category form submit', () async {
        final service = ref.read(categoryAppServiceProvider);
        final targetCategoryId = _categoryId;
        if (targetCategoryId == null) {
          await service.createCategory(
            CreateCategoryCommand(
              name: name,
              type: current.type,
              parentId: current.parentId,
              iconKey: current.iconKey,
              note: note,
            ),
          );
        } else {
          await service.editCategory(
            EditCategoryCommand(
              id: targetCategoryId,
              name: name,
              parentId:
                  current.parentId == null
                      ? const Patch<String>.clear()
                      : Patch.set(current.parentId!),
              iconKey: Patch.set(current.iconKey),
              note:
                  note == null ? const Patch<String>.clear() : Patch.set(note),
            ),
          );
        }
      });
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  void _update(CategoryFormState Function(CategoryFormState) update) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncValue.data(next);
  }

  SubmitOutcome _invalidCommand(String message) {
    return SubmitOutcome.failure(
      UiError(
        code: LedgerErrorCode.categoryInvalidCommand.code,
        message: message,
      ),
    );
  }
}

class CategoryFormState {
  CategoryFormState({
    required this.initialValues,
    required this.type,
    required this.iconKey,
    required this.submitting,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    this.parentId,
  }) : expenseTree = List.unmodifiable(expenseTree),
       incomeTree = List.unmodifiable(incomeTree);

  factory CategoryFormState.initial({
    required AccountType type,
    String? parentId,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
  }) {
    return CategoryFormState(
      initialValues: const CategoryFormInitialValues(),
      type: type,
      parentId: parentId,
      iconKey: defaultCategoryIconKey(type),
      submitting: false,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
    );
  }

  factory CategoryFormState.fromCategory(
    Account category, {
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
  }) {
    return CategoryFormState(
      initialValues: CategoryFormInitialValues.fromCategory(category),
      type: category.type,
      parentId: category.parentId,
      iconKey: category.iconKey ?? defaultCategoryIconKey(category.type),
      submitting: false,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
    );
  }

  final CategoryFormInitialValues initialValues;
  final AccountType type;
  final String? parentId;
  final String iconKey;
  final bool submitting;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;

  CategoryFormState copyWith({
    CategoryFormInitialValues? initialValues,
    AccountType? type,
    Object? parentId = _sentinel,
    String? iconKey,
    bool? submitting,
    List<CategoryNode>? expenseTree,
    List<CategoryNode>? incomeTree,
  }) {
    return CategoryFormState(
      initialValues: initialValues ?? this.initialValues,
      type: type ?? this.type,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      iconKey: iconKey ?? this.iconKey,
      submitting: submitting ?? this.submitting,
      expenseTree: expenseTree ?? this.expenseTree,
      incomeTree: incomeTree ?? this.incomeTree,
    );
  }
}

/// Text captured once from the category snapshot for controller construction.
/// This is not the live text state of the form.
class CategoryFormInitialValues {
  const CategoryFormInitialValues({this.name = '', this.note = ''});

  factory CategoryFormInitialValues.fromCategory(Account category) {
    return CategoryFormInitialValues(
      name: category.name,
      note: category.note ?? '',
    );
  }

  final String name;
  final String note;
}

String defaultCategoryIconKey(AccountType type) {
  return type == AccountType.income ? 'salary' : 'social';
}

List<Account> categoryParentOptions({
  required List<CategoryNode> nodes,
  required AccountType type,
  String? editingCategoryId,
}) {
  return [
    for (final node in nodes)
      if (node.account.type == type && node.account.id != editingCategoryId)
        node.account,
  ];
}

Account? findCategoryInTree(List<CategoryNode> nodes, String id) {
  for (final node in nodes) {
    if (node.account.id == id) return node.account;
    for (final child in node.children) {
      if (child.id == id) return child;
    }
  }
  return null;
}

const Object _sentinel = Object();
