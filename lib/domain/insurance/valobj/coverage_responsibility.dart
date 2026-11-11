import 'insurance_enums.dart';

class ResponsibilityPoint {
  const ResponsibilityPoint({
    required this.id,
    required this.label,
    required this.value,
    required this.order,
  });

  final String id;
  final String label;
  final String value;
  final int order;

  void validate() {
    if (label.trim().isEmpty || value.trim().isEmpty) {
      throw ArgumentError('Responsibility point label and value are required.');
    }
    if (order < 0) {
      throw ArgumentError.value(order, 'order', 'Order cannot be negative.');
    }
  }
}

class CoverageResponsibility {
  CoverageResponsibility({
    required this.id,
    required this.kind,
    required String name,
    required List<ResponsibilityPoint> points,
    required this.order,
  }) : name = name.trim(),
       points = List.unmodifiable(points);

  final String id;
  final ResponsibilityKind kind;
  final String name;
  final List<ResponsibilityPoint> points;
  final int order;

  void validate() {
    if (id.trim().isEmpty || name.isEmpty || order < 0) {
      throw ArgumentError('Coverage responsibility identity is invalid.');
    }
    final pointIds = <String>{};
    final labels = <String>{};
    for (final point in points) {
      point.validate();
      if (!pointIds.add(point.id)) {
        throw ArgumentError('Duplicate responsibility point id.');
      }
      if (!labels.add(point.label.trim())) {
        throw ArgumentError('Responsibility point labels must be unique.');
      }
    }
  }
}
