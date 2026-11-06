import '../../../../domain/insurance/valobj/insurance_enums.dart';
import '../../../../domain/insurance/valobj/social_contribution_record.dart';

class SaveSocialInsuranceCommand {
  const SaveSocialInsuranceCommand({
    this.id,
    required this.insuredPersonId,
    required this.region,
    required this.participantType,
    required this.contributionRecords,
  });

  final String? id;
  final String insuredPersonId;
  final String region;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
}
