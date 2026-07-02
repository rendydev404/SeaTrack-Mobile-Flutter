import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
class AppStateProvider extends ChangeNotifier {
  bool isNotificationAccessGranted = false;
  bool isBatteryOptimizationIgnored = false;
  List<String> logs = [];

  AppStateProvider() {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    isNotificationAccessGranted = await NotificationListenerService.isPermissionGranted();
    notifyListeners();
  }

  Future<void> requestNotificationAccess() async {
    await NotificationListenerService.requestPermission();
    await checkPermissions();
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
    logs.insert(0, '[$timestamp] $message');
    if (logs.length > 50) {
      logs.removeLast();
    }
    notifyListeners();
  }
}
