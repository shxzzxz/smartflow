import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/credit/product/installment_product_service.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/feature/credit/view_model/installment_product_view_model.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

class _Products extends Mock implements InstallmentProductService {}

void main() {
  setUpAll(() {
    registerFallbackValue(DayCountConvention.thirty360);
    registerFallbackValue(RoundingMode.halfUp);
  });

  for (final copy in [false, true]) {
    for (final saveError in [
      null,
      Exception('write failed'),
      StateError('invalid write'),
    ]) {
      test(
        'editing during ${copy ? 'copy' : 'create'} preserves the save guard (${saveError?.runtimeType ?? 'success'})',
        () async {
          final service = _Products();
          final draft = InstallmentTermsDraft.initial();
          when(() => service.list()).thenAnswer(
            (_) async => [
              InstallmentProductReadModel(
                id: 'source',
                name: '产品',
                archived: false,
                stages: draft.productRules(),
                dayCount: draft.dayCount,
                rounding: draft.rounding,
              ),
            ],
          );
          final gate = Completer<String>();
          var calls = 0;
          when(
            () => service.save(
              id: any(named: 'id'),
              name: any(named: 'name'),
              stages: any(named: 'stages'),
              dayCount: any(named: 'dayCount'),
              rounding: any(named: 'rounding'),
            ),
          ).thenAnswer((_) {
            calls++;
            return gate.future;
          });
          final container = ProviderContainer(
            overrides: [
              installmentProductServiceProvider.overrideWithValue(service),
            ],
          );
          addTearDown(container.dispose);
          final provider = installmentProductEditViewModelProvider(
            copy ? 'source' : null,
            copy,
          );
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          await container.read(provider.future);
          final vm = container.read(provider.notifier);

          final first = vm.save('产品');
          final firstResult = first.then<Object>(
            (value) => value,
            onError: (Object error) => error,
          );
          final edited = draft.copyWith(dayCount: DayCountConvention.thirty365);
          vm.setTerms(edited);
          final savingAfterEdit = container.read(provider).requireValue.saving;
          final second = vm.save('产品');
          if (saveError == null) {
            gate.complete('created');
          } else {
            gate.completeError(saveError);
          }
          final result = await firstResult;
          if (saveError is Error) {
            expect(result, same(saveError));
          } else if (saveError is Exception) {
            expect(result, isA<UiActionFailure<String>>());
          } else {
            expect(result, isA<UiActionSuccess<String>>());
          }
          final duplicate = await second;

          expect(savingAfterEdit, isTrue);
          expect(calls, 1);
          expect(duplicate, isA<UiActionFailure<String>>());
          expect(container.read(provider).requireValue.saving, isFalse);
          expect(container.read(provider).requireValue.terms, same(edited));
        },
      );
    }
  }
}
