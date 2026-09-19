import 'package:flutter/foundation.dart';

enum LogLevel { info, success, warning, error }

class LogEntry {
  final DateTime time;
  final String message;
  final LogLevel level;
  const LogEntry(this.time, this.message, this.level);
}

/// Riwayat aktivitas listener. Dipisah dari data transaksi supaya penambahan
/// log tidak memicu rebuild dashboard.
class ActivityLog extends ChangeNotifier {
  static const _max = 100;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);
  bool get isEmpty => _entries.isEmpty;
  LogEntry? get latest => _entries.isEmpty ? null : _entries.first;

  void add(String message, [LogLevel level = LogLevel.info]) {
    _entries.insert(0, LogEntry(DateTime.now(), message, level));
    if (_entries.length > _max) _entries.removeLast();
    notifyListeners();
  }

  void info(String m) => add(m);
  void success(String m) => add(m, LogLevel.success);
  void warn(String m) => add(m, LogLevel.warning);
  void error(String m) => add(m, LogLevel.error);

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
