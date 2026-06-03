import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'category_form_view_model.g.dart';

@riverpod
class CategoryFormViewModel extends _$CategoryFormViewModel {
  @override
  CategoryFormState build() {
    return CategoryFormState.initial();
  }

  void initializeNew({required AccountType type, String? parentId}) {
    if (state.initializedNew) return;
    state = state.copyWith(
      type: type,
      parentId: parentId,
      iconKey: defaultCategoryIconKey(type),
      initializedNew: true,
    );
  }

  void initializeForEdit(Account category) {
    if (state.initializedCategoryId == category.id) return;
    state = state.copyWith(
      type: category.type,
      parentId: category.parentId,
      iconKey: category.iconKey ?? defaultCategoryIconKey(category.type),
      initializedCategoryId: category.id,
    );
  }

  void setType(AccountType value) {
    if (state.type == value) return;
    state = state.copyWith(
      type: value,
      parentId: null,
      iconKey: defaultCategoryIconKey(value),
    );
  }

  void setParentId(String? value) {
    state = state.copyWith(parentId: value);
  }

  void setIconKey(String value) {
    if (state.iconKey == value) return;
    state = state.copyWith(iconKey: value);
  }

  Future<SubmitOutcome> submit({
    required String nameText,
    required String noteText,
    String? editCategoryId,
  }) async {
    final name = trimToNull(nameText);
    if (name == null) {
      return _invalidCommand('请输入分类名称');
    }
    final note = trimToNull(noteText);
    if (editCategoryId != null &&
        state.initializedCategoryId != editCategoryId) {
      return _invalidCommand('分类尚未加载。');
    }

    state = state.copyWith(submitting: true);
    try {
      final service = ref.read(categoryAppServiceProvider);
      if (editCategoryId == null) {
        await service.createCategory(
          CreateCategoryCommand(
            name: name,
            type: state.type,
            parentId: state.parentId,
            iconKey: state.iconKey,
            note: note,
          ),
        );
      } else {
        await service.editCategory(
          EditCategoryCommand(
            id: editCategoryId,
            name: name,
            parentId:
                state.parentId == null
                    ? const Patch<String>.clear()
                    : Patch.set(state.parentId!),
            iconKey: Patch.set(state.iconKey),
            note: note == null ? const Patch<String>.clear() : Patch.set(note),
          ),
        );
      }
      return const SubmitOutcome.success();
    } on BusinessException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on CallException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } finally {
      state = state.copyWith(submitting: false);
    }
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
  const CategoryFormState({
    required this.type,
    required this.iconKey,
    required this.submitting,
    required this.initializedNew,
    this.parentId,
    this.initializedCategoryId,
  });

  factory CategoryFormState.initial() {
    return CategoryFormState(
      type: AccountType.expense,
      iconKey: defaultCategoryIconKey(AccountType.expense),
      submitting: false,
      initializedNew: false,
    );
  }

  final AccountType type;
  final String? parentId;
  final String iconKey;
  final bool submitting;
  final bool initializedNew;
  final String? initializedCategoryId;

  CategoryFormState copyWith({
    AccountType? type,
    Object? parentId = _sentinel,
    String? iconKey,
    bool? submitting,
    bool? initializedNew,
    Object? initializedCategoryId = _sentinel,
  }) {
    return CategoryFormState(
      type: type ?? this.type,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      iconKey: iconKey ?? this.iconKey,
      submitting: submitting ?? this.submitting,
      initializedNew: initializedNew ?? this.initializedNew,
      initializedCategoryId:
          initializedCategoryId == _sentinel
              ? this.initializedCategoryId
              : initializedCategoryId as String?,
    );
  }
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
