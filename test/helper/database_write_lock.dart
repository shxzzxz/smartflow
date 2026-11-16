import 'dart:async';

import 'package:smartflow/infrastructure/database/app_database.dart';

Future<void> whileDatabaseWriteLocked(
  AppDatabase database,
  Future<void> Function() body, {
  Duration? releaseAfter,
}) async {
  final locked = Completer<void>();
  final released = Completer<void>();
  void release() {
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
  });
  Timer? timer;
  try {
    await Future.any([locked.future, writing]);
    if (releaseAfter != null) timer = Timer(releaseAfter, release);
    await body();
  } finally {
    timer?.cancel();
    release();
    await writing;
  }
}
