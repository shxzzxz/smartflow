import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}
