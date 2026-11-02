import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/transaction_account_options.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/transaction_form_state.dart';

void main() {
  test('freezes selected tag sets across snapshots', () {
    final selectedTags = {'tag-1'};
    final state = TransactionFormState.initial(
      mode: TransactionFormMode.expense,
      accountOptions: TransactionAccountOptions.empty(),
      expenseTree: const [],
      incomeTree: const [],
      tags: const [],
      counterparties: const [],
    ).copyWith(selectedTagIds: selectedTags);

    selectedTags.add('tag-2');

    expect(state.selectedTagIds, {'tag-1'});
    expect(() => state.selectedTagIds.add('tag-3'), throwsUnsupportedError);
  });
}
