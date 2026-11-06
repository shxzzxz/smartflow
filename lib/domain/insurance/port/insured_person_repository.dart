import '../entity/insured_person.dart';

abstract interface class InsuredPersonRepository {
  Future<List<InsuredPerson>> list();
  Future<InsuredPerson?> find(String id);
  Future<void> save(InsuredPerson person);
  Future<void> delete(String id);
}
