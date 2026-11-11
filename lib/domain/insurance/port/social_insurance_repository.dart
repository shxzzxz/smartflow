import '../entity/social_insurance.dart';

abstract interface class SocialInsuranceRepository {
  Future<List<SocialInsurance>> list({String? insuredPersonId});
  Future<SocialInsurance?> find(String id);
  Future<void> save(SocialInsurance insurance);
  Future<void> delete(String id);
  Future<bool> existsForInsuredPerson(String insuredPersonId);
}
