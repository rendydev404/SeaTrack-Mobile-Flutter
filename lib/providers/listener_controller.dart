import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../core/formatters.dart';
import '../core/sources.dart';
import '../services/battery_service.dart';
import '../services/notification_parser.dart';
import 'activity_log.dart';
import 'transaction_provider.dart';

/// Mengelola izin, stream notifikasi, dan siklus hidup aplikasi.
class ListenerController extends ChangeNotifier with WidgetsBindingObserver {
  ListenerController(this._tx, this._log);

  final TransactionProvider _tx;
  final ActivityLog _log;

  StreamSubscription<ServiceNotificationEvent>? _sub;
  final Set<int> _seen = {};
  Future<void> _queue = Future.value();

  bool _notifGranted = false;
  bool _batteryIgnored = false;
  bool _checkedOnce = false;
  DateTime? _lastCapture;

  bool get notificationGranted => _notifGranted;
  bool get batteryIgnored => _batteryIgnored;
  bool get ready => _checkedOnce;
  bool get listening => _sub != null;
  DateTime? get lastCapture => _lastCapture;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await refreshPermissions();
    if (_notifGranted) {
      _startStream();
      await sweepActive();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    refreshPermissions().then((_) async {
      if (_notifGranted && _sub == null) _startStream();
      await _tx.refresh();
      await sweepActive();
    });
  }

  Future<void> refreshPermissions() async {
    if (!Platform.isAndroid) {
      _checkedOnce = true;
      notifyListeners();
      return;
    }
    final results = await Future.wait([
      NotificationListenerService.isPermissionGranted(),
      BatteryService.isIgnoringOptimizations(),
    ]);
    _notifGranted = results[0];
    _batteryIgnored = results[1];
    _checkedOnce = true;
    notifyListeners();
  }

  Future<void> requestNotificationAccess() async {
    await NotificationListenerService.requestPermission();
    await refreshPermissions();
    if (_notifGranted && _sub == null) {
      _startStream();
      await sweepActive();
    }
  }

  Future<void> requestBatteryExemption() async {
    await BatteryService.requestIgnore();
  }

  void _startStream() {
    if (!Platform.isAndroid || _sub != null) return;
    _sub = NotificationListenerService.notificationsStream.listen(
      _enqueue,
      onError: (Object e) => _log.error('Stream notifikasi error: $e'),
    );
    _log.info('Listener aktif');
    notifyListeners();
  }

  /// Membaca notifikasi yang masih ada di panel; menangkap transaksi yang
  /// terlewat saat aplikasi tidak berjalan.
  Future<void> sweepActive() async {
    if (!_notifGranted || !Platform.isAndroid) return;
    try {
      final events = await NotificationListenerService.getActiveNotifications();
      for (final e in events) {
        _enqueue(e);
      }
    } catch (e) {
      _log.warn('Gagal membaca notifikasi aktif: $e');
    }
  }

  /// Pemrosesan diserialkan agar event yang sama dari stream dan sweep tidak
  /// masuk ganda ke database.
  void _enqueue(ServiceNotificationEvent e) {
    _queue = _queue.then((_) => _handle(e)).catchError((Object err) {
      _log.error('Gagal memproses notifikasi: $err');
    });
  }

  Future<void> _handle(ServiceNotificationEvent e) async {
    if (e.hasRemoved || e.onGoing) return;
    final source = TxSource.fromPackage(e.packageName);
    if (source == null) return;

    final key = Object.hash(e.packageName, e.timestamp, e.content);
    if (_seen.contains(key)) return;
    _seen.add(key);
    if (_seen.length > 500) _seen.remove(_seen.first);

    final parsed = NotificationParser.parse(
      packageName: e.packageName,
      title: e.title,
      content: e.content,
      timestampMs: e.timestamp,
    );
    if (parsed == null) {
      _log.info('${source.label}: bukan transaksi, diabaikan');
      return;
    }
    if (await _tx.existsAt(parsed.createdAt)) {
      _log.info('${source.label}: sudah tercatat, dilewati');
      return;
    }
    try {
      await _tx.add(parsed);
      _lastCapture = DateTime.now();
      _log.success(
        '${source.label}: ${parsed.type.label} ${Fmt.idr(parsed.amount)} tersimpan',
      );
      notifyListeners();
    } catch (err) {
      _seen.remove(key);
      _log.error('${source.label}: gagal simpan (${_short(err)})');
    }
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 80 ? '${s.substring(0, 77)}…' : s;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }
}
