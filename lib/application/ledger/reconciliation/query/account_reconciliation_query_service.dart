import 'dart:async';

import '../port/account_reconciliation_repository.dart';
import 'account_reconciliation_queries.dart';
import 'account_reconciliation_read_models.dart';

abstract interface class AccountReconciliationQueryService {
  Stream<AccountReconciliationState> watch(AccountReconciliationQuery query);
}

class AccountReconciliationQueryServiceImpl
    implements AccountReconciliationQueryService {
  const AccountReconciliationQueryServiceImpl(this._repository);

  final AccountReconciliationRepository _repository;

  @override
  Stream<AccountReconciliationState> watch(AccountReconciliationQuery query) {
    final current = _repository.watchCurrentDays(query);
    final snapshots = _repository.watchSnapshots(query);
    return Stream.multi((controller) {
      List<DailyAccountLedgerState>? latestCurrent;
      List<AccountReconciliationDaySnapshot>? latestSnapshots;
      StreamSubscription<List<DailyAccountLedgerState>>? currentSubscription;
      StreamSubscription<List<AccountReconciliationDaySnapshot>>?
      snapshotSubscription;
      var cancelled = false;
      var completedCount = 0;

      void emitIfReady() {
        final current = latestCurrent;
        final snapshots = latestSnapshots;
        if (cancelled || current == null || snapshots == null) return;
        controller.add(
          AccountReconciliationState(
            currentDays: {for (final day in current) day.ledgerDateKey: day},
            snapshotDays: {for (final day in snapshots) day.ledgerDateKey: day},
          ),
        );
      }

      Future<void> cancelAll() async {
        await currentSubscription?.cancel();
        await snapshotSubscription?.cancel();
      }

      Future<void> closeAll() async {
        if (cancelled) return;
        cancelled = true;
        await cancelAll();
        await controller.close();
      }

      void handleDone() {
        completedCount += 1;
        if (completedCount == 2) unawaited(closeAll());
      }

      currentSubscription = current.listen(
        (value) {
          latestCurrent = value;
          emitIfReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
          unawaited(closeAll());
        },
        onDone: handleDone,
        cancelOnError: true,
      );
      snapshotSubscription = snapshots.listen(
        (value) {
          latestSnapshots = value;
          emitIfReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
          unawaited(closeAll());
        },
        onDone: handleDone,
        cancelOnError: true,
      );

      controller.onCancel = () {
        cancelled = true;
        return cancelAll();
      };
    });
  }
}
