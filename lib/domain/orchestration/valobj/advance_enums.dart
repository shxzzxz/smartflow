const String orchestrationAdvanceOwnerType = 'orchestration.advance';

enum AdvanceScenario {
  aa,
  onBehalf,
  reimbursement;

  static AdvanceScenario? fromWire(String? value) {
    for (final scenario in values) {
      if (scenario.name == value) return scenario;
    }
    return null;
  }
}

enum AdvanceTrackingMode {
  itemized,
  account;

  static AdvanceTrackingMode? fromWire(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
