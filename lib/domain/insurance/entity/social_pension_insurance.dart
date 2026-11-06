import '../valobj/insurance_enums.dart';
import '../valobj/social_contribution_record.dart';

class SocialPensionInsurance {
  SocialPensionInsurance({
    required this.id,
    required this.insuredPersonId,
    required String region,
    required this.participantType,
    required List<SocialContributionRecord> contributionRecords,
    required this.createdAt,
    required this.updatedAt,
  }) : region = region.trim(),
       contributionRecords = List.unmodifiable(contributionRecords);

  final String id;
  final String insuredPersonId;
  final String region;
  final SocialParticipantType participantType;
  final List<SocialContributionRecord> contributionRecords;
  final DateTime createdAt;
  final DateTime updatedAt;

  void validate() {
    if (id.trim().isEmpty || insuredPersonId.trim().isEmpty || region.isEmpty) {
      throw ArgumentError('Social insurance basic fields are required.');
    }
    final months = <String>{};
    for (final record in contributionRecords) {
      record.validate();
      if (!months.add(record.month.toString())) {
        throw ArgumentError('Contribution months must be unique.');
      }
    }
  }
}
