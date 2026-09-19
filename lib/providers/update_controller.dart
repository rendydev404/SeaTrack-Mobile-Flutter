import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/update_config.dart';
import '../services/update_service.dart';

/// Menjaga status pembaruan tetap segar dan memicu pengecekan saat aplikasi
/// kembali ke depan. Pengunduhan dan pemasangan dikerjakan sisi native, jadi
/// kelas ini hanya meneruskan perintah dan menyiarkan status ke UI.
class UpdateController extends ChangeNotifier with WidgetsBindingObserver {
  UpdateController({String manifestUrl = kUpdateManifestUrl})
      : _manifestUrl = manifestUrl.trim();

  final String _manifestUrl;
  StreamSubscription<UpdateStatus>? _sub;
  UpdateStatus _status = const UpdateStatus();

  UpdateStatus get status => _status;
  UpdateState get state => _status.state;
  UpdateRelease? get release => _status.release;

  /// Fitur hanya hidup bila URL manifest terisi saat build.
  bool get enabled => _manifestUrl.isNotEmpty && UpdateService.supported;

  /// Benar saat ada sesuatu yang layak ditampilkan di dashboard.
  bool get hasBanner =>
      enabled &&
      (_status.justInstalledVersion != null ||
          switch (_status.state) {
            UpdateState.available ||
            UpdateState.downloading ||
            UpdateState.ready ||
            UpdateState.installing ||
            UpdateState.needsPermission =>
              true,
            _ => false,
          });

  Future<void> init() async {
    if (!enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _sub = UpdateService.statusStream.listen(
      (s) {
        _status = s;
        notifyListeners();
      },
      onError: (Object e) => debugPrint('Update stream error: $e'),
    );
    final initial = await UpdateService.initialize(_manifestUrl);
    if (initial != null) {
      _status = initial;
      notifyListeners();
    }
    await UpdateService.check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled || state != AppLifecycleState.resumed) return;
    // Pengguna mungkin baru saja memberi izin pasang di layar pengaturan sistem.
    UpdateService.resumeAfterPermission();
    UpdateService.check();
  }

  Future<void> checkNow() => UpdateService.check(force: true);
  Future<void> install() => UpdateService.install();
  Future<void> grantAndInstall() => UpdateService.continueWithUserAction();
  Future<void> requestRelaunchPermission() =>
      UpdateService.requestOverlayPermission();

  Future<void> dismissInstalledNotice() async {
    await UpdateService.acknowledgeInstall();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }
}
