import '../entity/social_medical_insurance.dart';
import '../entity/social_pension_insurance.dart';

abstract interface class SocialInsuranceRepository {
  Future<List<SocialMedicalInsurance>> listMedical({String? insuredPersonId});
  Future<SocialMedicalInsurance?> findMedical(String id);
  Future<void> saveMedical(SocialMedicalInsurance insurance);
  Future<void> deleteMedical(String id);

  Future<List<SocialPensionInsurance>> listPension({String? insuredPersonId});
  Future<SocialPensionInsurance?> findPension(String id);
  Future<void> savePension(SocialPensionInsurance insurance);
  Future<void> deletePension(String id);

  Future<bool> existsForInsuredPerson(String insuredPersonId);
}
