/// Application-level hook for rebuilding read-side state after a database
/// lifecycle operation such as a snapshot restore.
abstract interface class AppDataRefresh {
  void refresh();
}
