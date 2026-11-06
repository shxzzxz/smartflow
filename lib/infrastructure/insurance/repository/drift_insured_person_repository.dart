import 'package:drift/drift.dart';

import '../../../domain/insurance/entity/insured_person.dart';
import '../../../domain/insurance/port/insured_person_repository.dart';
import '../../database/app_database.dart';

class DriftInsuredPersonRepository implements InsuredPersonRepository {
  const DriftInsuredPersonRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<InsuredPerson>> list() async {
    final query = _database.select(_database.insuredPeople)
      ..orderBy([
        (row) => OrderingTerm(expression: row.createdAt),
        (row) => OrderingTerm(expression: row.id),
      ]);
    return [for (final row in await query.get()) _toDomain(row)];
  }

  @override
  Future<InsuredPerson?> find(String id) async {
    final query = _database.select(_database.insuredPeople)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(InsuredPerson person) async {
    await _database
        .into(_database.insuredPeople)
        .insertOnConflictUpdate(
          InsuredPeopleCompanion.insert(
            id: person.id,
            name: person.name,
            birthDate: person.birthDate,
            relationship: Value(person.relationship),
            gender: Value(person.gender),
            note: Value(person.note),
            avatarPreset: Value(person.avatarPreset),
            createdAt: Value(person.createdAt),
            updatedAt: Value(person.updatedAt),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.insuredPeople,
    )..where((row) => row.id.equals(id))).go();
  }

  InsuredPerson _toDomain(InsuredPersonRow row) {
    return InsuredPerson(
      id: row.id,
      name: row.name,
      birthDate: row.birthDate,
      relationship: row.relationship,
      gender: row.gender,
      note: row.note,
      avatarPreset: row.avatarPreset,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
