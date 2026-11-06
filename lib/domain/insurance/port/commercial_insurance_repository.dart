import '../entity/commercial_insurance.dart';

abstract interface class CommercialInsuranceRepository {
  Future<List<CommercialInsurance>> list({String? insuredPersonId});
  Future<CommercialInsurance?> find(String id);
  Future<bool> existsForInsuredPerson(String insuredPersonId);
  Future<void> save(CommercialInsurance insurance);
  Future<void> delete(String id);
}
