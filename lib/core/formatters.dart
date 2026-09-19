import 'package:intl/intl.dart';

/// Formatter dibuat sekali dan dipakai ulang karena NumberFormat mahal untuk dibuat.
class Fmt {
  Fmt._();

  static final NumberFormat _idr =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final NumberFormat _compact =
      NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 1);
  static final DateFormat _time = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _dayHeader = DateFormat('EEEE, d MMM yyyy', 'id_ID');
  static final DateFormat _full = DateFormat('d MMMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _weekday = DateFormat('EEE', 'id_ID');
  static final DateFormat _month = DateFormat('MMMM yyyy', 'id_ID');

  static String idr(num v) => _idr.format(v);
  static String compact(num v) => _compact.format(v);
  static String signed(num v, bool income) =>
      '${income ? '+' : '-'}${_idr.format(v)}';
  static String time(DateTime d) => _time.format(d.toLocal());
  static String full(DateTime d) => _full.format(d.toLocal());
  static String weekday(DateTime d) => _weekday.format(d.toLocal());
  static String month(DateTime d) => _month.format(d.toLocal());

  static String dayHeader(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return _dayHeader.format(local);
  }
}
