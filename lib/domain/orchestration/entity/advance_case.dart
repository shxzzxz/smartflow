import '../valobj/advance_enums.dart';

class AdvanceCase {
  const AdvanceCase({
    required this.id,
    required this.scenario,
    required this.trackingMode,
    this.receivableAccountId,
    this.aaPeopleCount,
  });

  final String id;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final String? receivableAccountId;
  final int? aaPeopleCount;

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Advance case id is required.');
    }
    if (trackingMode == AdvanceTrackingMode.account &&
        (receivableAccountId == null || receivableAccountId!.trim().isEmpty)) {
      throw ArgumentError(
        'Account-tracked advances require a receivable account.',
      );
    }
    if (scenario == AdvanceScenario.aa &&
        trackingMode == AdvanceTrackingMode.itemized) {
      final people = aaPeopleCount;
      if (people == null || people < 2 || people > 99) {
        throw ArgumentError.value(
          people,
          'aaPeopleCount',
          'AA advances require 2 to 99 participants.',
        );
      }
    } else if (scenario != AdvanceScenario.aa && aaPeopleCount != null) {
      throw ArgumentError(
        'Only AA advances can carry an AA participant count.',
      );
    } else if (aaPeopleCount != null &&
        (aaPeopleCount! < 2 || aaPeopleCount! > 99)) {
      throw ArgumentError.value(
        aaPeopleCount,
        'aaPeopleCount',
        'AA advances require 2 to 99 participants.',
      );
    }
  }

  AdvanceCase copyWith({
    AdvanceScenario? scenario,
    AdvanceTrackingMode? trackingMode,
    String? receivableAccountId,
    int? aaPeopleCount,
  }) {
    return AdvanceCase(
      id: id,
      scenario: scenario ?? this.scenario,
      trackingMode: trackingMode ?? this.trackingMode,
      receivableAccountId: receivableAccountId ?? this.receivableAccountId,
      aaPeopleCount: aaPeopleCount ?? this.aaPeopleCount,
    );
  }
}
