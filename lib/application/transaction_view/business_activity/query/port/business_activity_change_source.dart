import '../business_activity_queries.dart';

/// Invalidates a complete page when its candidate or content dependencies change.
abstract interface class BusinessActivityChangeSource {
  /// Subscribes before emitting the initial notification. Each subsequent
  /// notification represents a committed batch affecting the enabled sources.
  Stream<void> watchChanges(BusinessActivityPageQuery query);
}
