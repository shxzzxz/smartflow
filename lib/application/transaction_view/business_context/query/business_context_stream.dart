import 'dart:async';

Stream<List<T>> combineLatestStreams<T>(Iterable<Stream<T>> streams) {
  final values = List<Stream<T>>.unmodifiable(streams);
  if (values.isEmpty) return Stream.value(const []);
  return Stream.multi((controller) {
    final latest = List<T?>.filled(values.length, null);
    final subscriptions = List<StreamSubscription<T>?>.filled(
      values.length,
      null,
    );
    var cancelled = false;

    Future<void> cancelAll() async {
      for (final subscription in subscriptions) {
        await subscription?.cancel();
      }
    }

    for (var index = 0; index < values.length; index++) {
      subscriptions[index] = values[index].listen(
        (value) {
          if (cancelled) return;
          latest[index] = value;
          if (latest.every((value) => value != null)) {
            controller.add(List<T>.unmodifiable(latest.cast<T>()));
          }
        },
        onError: controller.addError,
        onDone: () {
          if (cancelled) return;
          cancelled = true;
          unawaited(cancelAll());
          controller.close();
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

    Future<void> cancelMapped() async {
      await mappedSubscription?.cancel();
      mappedSubscription = null;
    }

    sourceSubscription = source.listen(
      (value) {
        if (cancelled) return;
        final currentGeneration = ++generation;
        unawaited(cancelMapped());
        mappedSubscription = mapper(value).listen((mapped) {
          if (!cancelled && currentGeneration == generation) {
            controller.add(mapped);
          }
        }, onError: controller.addError);
      },
      onError: controller.addError,
      onDone: () async {
        cancelled = true;
        await cancelMapped();
        await controller.close();
      },
      cancelOnError: true,
    );

    controller.onCancel = () async {
      cancelled = true;
      await sourceSubscription?.cancel();
      await cancelMapped();
    };
  });
}
