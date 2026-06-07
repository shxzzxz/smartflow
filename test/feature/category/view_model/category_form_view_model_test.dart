import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/category/view_model/category_form_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('CategoryFormViewModel', () {
    test('creates category command and returns success', () async {
      final service = _FakeCategoryAppService();
      final container = _container(service);
      final viewModel = container.read(categoryFormViewModelProvider.notifier);

      viewModel
        ..initializeNew(type: AccountType.income)
        ..setParentId('parent-1');

      final outcome = await viewModel.submit(
        nameText: ' Salary ',
        noteText: ' monthly ',
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(container.read(categoryFormViewModelProvider).submitting, false);
      final command = service.createCommands.single;
      expect(command.name, 'Salary');
      expect(command.type, AccountType.income);
      expect(command.parentId, 'parent-1');
      expect(command.note, 'monthly');
    });

    test('edits loaded category through edit command', () async {
      final service = _FakeCategoryAppService();
      final container = _container(service);
      final viewModel = container.read(categoryFormViewModelProvider.notifier);

      viewModel.initializeForEdit(
        _category('category-1', name: 'Food', parentId: 'old-parent'),
      );
      viewModel.setParentId('new-parent');

      final outcome = await viewModel.submit(
        nameText: 'Dining',
        noteText: '',
        editCategoryId: 'category-1',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = service.editCommands.single;
      expect(command.id, 'category-1');
      expect(command.name, 'Dining');
      expect(command.parentId, isA<PatchSet<String>>());
      expect((command.parentId as PatchSet<String>).value, 'new-parent');
      expect(command.note, isA<PatchClear<String>>());
    });

    test('maps business exception to submit failure', () async {
      final service = _FakeCategoryAppService(
        exception: BusinessException(
          LedgerErrorCode.categoryInvalidParent,
          message: '已有子分类，不能设为子分类。',
        ),
      );
      final container = _container(service);
      final viewModel = container.read(categoryFormViewModelProvider.notifier);

      viewModel
        ..initializeForEdit(_category('category-1'))
        ..setParentId('parent-1');

      final outcome = await viewModel.submit(
        nameText: 'Food',
        noteText: '',
        editCategoryId: 'category-1',
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, LedgerErrorCode.categoryInvalidParent.code);
      expect(failure.error.message, '已有子分类，不能设为子分类。');
      expect(container.read(categoryFormViewModelProvider).submitting, false);
    });
  });
}

ProviderContainer _container(_FakeCategoryAppService service) {
  final container = ProviderContainer(
    overrides: [categoryAppServiceProvider.overrideWith((ref) => service)],
  );
  addTearDown(container.dispose);
  return container;
}

Account _category(String id, {String? name, String? parentId}) {
  return Account(
    id: id,
    name: name ?? id,
    type: AccountType.expense,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeCategoryAppService implements CategoryAppService {
  _FakeCategoryAppService({this.exception});

  final Object? exception;
  final createCommands = <CreateCategoryCommand>[];
  final editCommands = <EditCategoryCommand>[];

  @override
  Future<Account> createCategory(CreateCategoryCommand command) async {
    createCommands.add(command);
    _throwIfNeeded();
    return _category('created', name: command.name);
  }

  @override
  Future<void> editCategory(EditCategoryCommand command) async {
    editCommands.add(command);
    _throwIfNeeded();
  }

  void _throwIfNeeded() {
    final exception = this.exception;
    if (exception != null) throw exception;
  }
}
