/// A local wall-clock time, without Flutter or a specific calendar date.
class NotificationTime {
  const NotificationTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  static NotificationTime? fromMinutes(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
    return NotificationTime(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is NotificationTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
