import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';

part 'counterparty_management_view_model.g.dart';

final _logger = Logger('feature.counterparty');

enum CounterpartyCommandOutcome { success, duplicateName, unknown }

@riverpod
class CounterpartyManagementViewModel
    extends _$CounterpartyManagementViewModel {
  CounterpartyApplicationService get _service =>
      ref.read(counterpartyApplicationServiceProvider);

  @override
  void build() {}

  Future<CounterpartyCommandOutcome> create(String name) {
    return _run(() => _service.createCounterparty(name));
  }

  Future<CounterpartyCommandOutcome> rename({
    required String id,
    required String name,
  }) {
    return _run(
      () => _service.renameCounterparty(id: id, name: name),
      duplicateOnStateError: true,
    );
  }

  Future<CounterpartyCommandOutcome> delete(String id) {
    return _run(() => _service.deleteCounterparty(id));
  }

  Future<CounterpartyCommandOutcome> _run(
    Future<void> Function() action, {
    bool duplicateOnStateError = false,
  }) async {
    try {
      await action();
      return CounterpartyCommandOutcome.success;
    } on StateError catch (error, stackTrace) {
      if (duplicateOnStateError) {
        return CounterpartyCommandOutcome.duplicateName;
      }
      _logger.severe('Counterparty command failed.', error, stackTrace);
      return CounterpartyCommandOutcome.unknown;
    } on Exception catch (error, stackTrace) {
      _logger.severe('Counterparty command failed.', error, stackTrace);
      return CounterpartyCommandOutcome.unknown;
    }
  }
}
