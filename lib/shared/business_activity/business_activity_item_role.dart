/// A business activity item's relationship to its owning activity.
enum BusinessActivityItemRole {
  /// Defines the activity identity.
  origin,

  /// Advances an activity that is already defined by an origin item.
  followUp,
}
