import 'package:notification_listener_service/notification_event.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

class NotificationService {
  static void processNotification(ServiceNotificationEvent event, Function(String) onLog) {
    if (event.packageName != 'com.seabank.id') {
      return; // Ignore notifications from other apps
    }

    final title = event.title ?? '';
    final content = event.content ?? '';
    final text = '$title $content'.toLowerCase();
    
    onLog('Received SeaBank Notification: $content');

    TransactionModel? transaction = _parseNotification(text, content);

    if (transaction != null) {
      onLog('Parsed: ${transaction.type} - Rp ${transaction.amount}');
      SupabaseService.insertTransaction(transaction);
    } else {
      onLog('Failed to parse or not a transaction notification.');
    }
  }

  static TransactionModel? _parseNotification(String lowerText, String originalText) {
    // Check for Income
    if (lowerText.contains('masuk') || lowerText.contains('dikreditkan')) {
      final amount = _extractAmount(originalText);
      if (amount != null) {
        return TransactionModel(
          title: 'Transfer Masuk / Bunga',
          amount: amount,
          type: 'income',
        );
      }
    }
    
    // Check for Expense
    if (lowerText.contains('keluar') || lowerText.contains('qris')) {
      final amount = _extractAmount(originalText);
      if (amount != null) {
        return TransactionModel(
          title: 'Transfer Keluar / QRIS',
          amount: amount,
          type: 'expense',
        );
      }
    }

    return null;
  }

  static double? _extractAmount(String text) {
    // Matches "Rp " followed by numbers and dots, up to a space or end of string.
    final RegExp regex = RegExp(r'Rp\s?([\d\.]+)');
    final match = regex.firstMatch(text);

    if (match != null && match.groupCount >= 1) {
      String amountStr = match.group(1)!;
      // Remove dots
      amountStr = amountStr.replaceAll('.', '');
      return double.tryParse(amountStr);
    }
    return null;
  }
}
