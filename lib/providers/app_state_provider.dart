import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import 'dart:async';

class AppStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool isNotificationAccessGranted = false;
  List<String> logs = [];
  
  List<TransactionModel> transactions = [];
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double balance = 0.0;

  final TransactionRepository _repository = TransactionRepository();
  Timer? _pollingTimer;
  StreamSubscription? _realtimeSubscription;

  AppStateProvider() {
    WidgetsBinding.instance.addObserver(this);
    checkPermissions();
    _initRealtimeTransactions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force refresh when app comes back to foreground
      fetchTransactions();
    }
  }

  void _initRealtimeTransactions() {
    // 1. Fetch immediately
    fetchTransactions();
    
    // 2. Fallback polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchTransactions();
    });

    // 3. True Supabase Realtime Stream (if replication is enabled)
    _realtimeSubscription = _repository.getTransactionsStream().listen((data) {
      transactions = data;
      _calculateTotals();
      notifyListeners();
    });
  }

  Future<void> fetchTransactions() async {
    try {
      final data = await _repository.getTransactions();
      // Always update to guarantee 100% realtime feel
      transactions = data;
      _calculateTotals();
      notifyListeners();
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  void _calculateTotals() {
    totalIncome = 0.0;
    totalExpense = 0.0;
    
    for (var tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      }
    }
    balance = totalIncome - totalExpense;
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

  Future<void> addManualTransaction(TransactionModel transaction) async {
    try {
      await _repository.insertTransaction(transaction);
      addLog('Manual transaction added: Rp ${transaction.amount}');
      await fetchTransactions(); // Instantly reload UI
    } catch (e) {
      addLog('Error adding transaction: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
