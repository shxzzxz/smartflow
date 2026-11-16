import 'dart:async';

import 'package:smartflow/infrastructure/database/app_database.dart';

Future<void> whileDatabaseWriteLocked(
  AppDatabase database,
  Future<void> Function() body, {
  Duration? releaseAfter,
}) async {
  final elapsed = Stopwatch()..start();
  final locked = Completer<void>();
  final released = Completer<void>();
  void release() {
    // ignore: avoid_print
    print('[DEBUG-v098-lock] release at ${elapsed.elapsedMilliseconds}ms');
    if (!released.isCompleted) released.complete();
  }

  final writing = database.transaction(() async {
    await database
        .into(database.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: 'test.concurrent_write',
            value: 'held',
          ),
        );
    locked.complete();
    await released.future;
    // ignore: avoid_print
    print(
      '[DEBUG-v098-lock] commit starts at ${elapsed.elapsedMilliseconds}ms',
    );
  });
  Timer? timer;
  try {
    await Future.any([locked.future, writing]);
    // ignore: avoid_print
    print('[DEBUG-v098-lock] locked at ${elapsed.elapsedMilliseconds}ms');
    if (releaseAfter != null) timer = Timer(releaseAfter, release);
    await body();
  } finally {
    // ignore: avoid_print
    print(
      '[DEBUG-v098-lock] body finishes at ${elapsed.elapsedMilliseconds}ms',
    );
    timer?.cancel();
    release();
    await writing;
  }
}
