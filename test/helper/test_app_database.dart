import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Override testAppDatabaseOverride() {
  return appDatabaseProvider.overrideWith((ref) {
    final database = createTestDatabase();
    ref.onDispose(database.close);
    return database;
  });
}
