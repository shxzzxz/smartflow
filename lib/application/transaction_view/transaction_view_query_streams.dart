import 'dart:async';

/// Stream combinators shared by transaction-view query orchestration.
Stream<List<T>> combineLatestStreams<T>(Iterable<Stream<T>> streams) {
  final values = List<Stream<T>>.unmodifiable(streams);
  if (values.isEmpty) return Stream.value(const []);
  return Stream.multi((controller) {
    final latest = List<T?>.filled(values.length, null);
    final hasValue = List<bool>.filled(values.length, false);
    final subscriptions = List<StreamSubscription<T>?>.filled(
      values.length,
      null,
    );
    var cancelled = false;
    var completedCount = 0;

    Future<void> cancelAll() async {
      for (final subscription in subscriptions) {
        await subscription?.cancel();
      }
    }

    Future<void> closeAll() async {
      if (cancelled) return;
      cancelled = true;
      await cancelAll();
      await controller.close();
    }

    for (var index = 0; index < values.length; index++) {
      subscriptions[index] = values[index].listen(
        (value) {
          if (cancelled) return;
          latest[index] = value;
          hasValue[index] = true;
          if (hasValue.every((value) => value)) {
            controller.add(List<T>.unmodifiable(latest.cast<T>()));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
          unawaited(closeAll());
        },
        onDone: () {
          if (cancelled) return;
          completedCount += 1;
          if (completedCount == values.length) {
            unawaited(closeAll());
          }
        },
        cancelOnError: true,
      );
    }

    controller.onCancel = () {
      cancelled = true;
      return cancelAll();
    };
  });
}

Stream<R> switchMapStreams<T, R>(
  Stream<T> source,
  Stream<R> Function(T value) mapper,
) {
  return Stream.multi((controller) {
    StreamSubscription<T>? sourceSubscription;
    StreamSubscription<R>? mappedSubscription;
    var generation = 0;
    var cancelled = false;

    Future<void> cancelMapped(StreamSubscription<R>? subscription) async {
      await subscription?.cancel();
    }

    sourceSubscription = source.listen(
      (value) {
        if (cancelled) return;
        final currentGeneration = ++generation;
        final previous = mappedSubscription;
        mappedSubscription = null;
        unawaited(cancelMapped(previous));
        mappedSubscription = mapper(value).listen((mapped) {
          if (!cancelled && currentGeneration == generation) {
            controller.add(mapped);
          }
        }, onError: controller.addError);
      },
      onError: controller.addError,
      onDone: () async {
        cancelled = true;
        final subscription = mappedSubscription;
        mappedSubscription = null;
        await cancelMapped(subscription);
        await controller.close();
      },
      cancelOnError: true,
    );

    controller.onCancel = () async {
      cancelled = true;
      await sourceSubscription?.cancel();
      final subscription = mappedSubscription;
      mappedSubscription = null;
      await cancelMapped(subscription);
    };
  });
}
