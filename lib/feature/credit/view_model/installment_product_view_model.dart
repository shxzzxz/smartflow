import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'installment_terms_draft.dart';

part 'installment_product_view_model.g.dart';

final _logger = Logger('feature.credit.products');

@riverpod
class InstallmentProductsViewModel extends _$InstallmentProductsViewModel {
  @override
  Future<List<InstallmentProductReadModel>> build() =>
      ref.watch(installmentProductServiceProvider).list();

  Future<UiActionOutcome<void>> archive(String id, bool archived) =>
      guardUiAction(_logger, 'Archive installment product', () async {
        await ref
            .read(installmentProductServiceProvider)
            .setArchived(id, archived);
        ref.invalidateSelf();
      });
  Future<UiActionOutcome<void>> delete(String id) =>
      guardUiAction(_logger, 'Delete installment product', () async {
        await ref.read(installmentProductServiceProvider).delete(id);
        ref.invalidateSelf();
      });
}

class InstallmentProductEditState {
  const InstallmentProductEditState({
    required this.terms,
    this.name = '',
    this.saving = false,
  });
  final String name;
  final InstallmentTermsDraft terms;
  final bool saving;
}

@riverpod
class InstallmentProductEditViewModel
    extends _$InstallmentProductEditViewModel {
  @override
  Future<InstallmentProductEditState> build(
    String? productId,
    bool copy,
  ) async {
    if (productId == null) {
      return InstallmentProductEditState(
        terms: InstallmentTermsDraft.initial(),
      );
    }
    final products = await ref.watch(installmentProductServiceProvider).list();
    final product = products.where((p) => p.id == productId).first;
    return InstallmentProductEditState(
      name: '${product.name}${copy ? ' 副本' : ''}',
      terms: InstallmentTermsDraft.product(
        product.stages,
        product.dayCount,
        product.rounding,
      ),
    );
  }

  void setTerms(InstallmentTermsDraft terms) {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        InstallmentProductEditState(name: current.name, terms: terms),
      );
    }
  }

  Future<UiActionOutcome<String>> save(String name) async {
    final current = state.requireValue;
    state = AsyncData(
      InstallmentProductEditState(
        name: name,
        terms: current.terms,
        saving: true,
      ),
    );
    final outcome = await guardUiAction(
      _logger,
      'Save installment product',
      () async {
        final id = await ref
            .read(installmentProductServiceProvider)
            .save(
              id: copy ? null : productId,
              name: name,
              stages: current.terms.productRules(),
              dayCount: current.terms.dayCount,
              rounding: current.terms.rounding,
            );
        ref.invalidate(installmentProductsViewModelProvider);
        return id;
      },
    );
    state = AsyncData(
      InstallmentProductEditState(name: name, terms: current.terms),
    );
    return outcome;
  }
}
