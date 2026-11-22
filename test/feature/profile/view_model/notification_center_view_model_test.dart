import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/app/provider_error_observer.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_message.dart';
import 'package:smartflow/feature/profile/view_model/notification_center_view_model.dart';

import '../../../helper/fake_notification_delivery.dart';

class _InboxStore extends MemoryNotificationInboxStore {
  bool fail = false;
  final failure = Exception('Cannot load notification history.');

  @override
  Stream<List<NotificationMessage>> watch() =>
      fail ? Stream.error(failure) : super.watch();
}

void main() {
  test(
    'one refresh failure is logged once and independent retries still log',
    () async {
      final records = <LogRecord>[];
      final rootLogs = Logger.root.onRecord.listen(records.add);
      addTearDown(rootLogs.cancel);
      final observerLogger = Logger.detached('test.notifications.provider');
      final providerLogs = observerLogger.onRecord.listen(records.add);
      addTearDown(providerLogs.cancel);
      final store = _InboxStore();
      addTearDown(store.dispose);
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        observers: [AppProviderErrorObserver(logger: observerLogger)],
        overrides: [
          notificationInboxServiceProvider.overrideWithValue(
            NotificationInboxService(store: store),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        notificationCenterViewModelProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);

      Future<void> settle() async {
        await pumpEventQueue();
        await container.pump();
      }

      await settle();
      expect(
        container.read(notificationCenterViewModelProvider).hasValue,
        isTrue,
      );
      final notifier = container.read(
        notificationCenterViewModelProvider.notifier,
      );

      store.fail = true;
      notifier.refresh();
      await settle();
      expect(
        container.read(notificationCenterViewModelProvider).hasError,
        isTrue,
      );
      expect(
        records.where((record) => record.level == Level.SEVERE),
        hasLength(1),
      );
      expect(records.single.error, same(store.failure));

      store.fail = false;
      notifier.refresh();
      await settle();
      expect(
        container.read(notificationCenterViewModelProvider).hasError,
        isFalse,
      );
      expect(records, hasLength(1));

      store.fail = true;
      notifier.refresh();
      await settle();
      expect(
        container.read(notificationCenterViewModelProvider).hasError,
        isTrue,
      );
      expect(
        records.where((record) => record.level == Level.SEVERE),
        hasLength(2),
      );
    },
  );
}
