import 'package:notification_listener_service/notification_event.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class NotificationService {
  static final TransactionRepository _repository = TransactionRepository();

  static Future<bool> processNotification(ServiceNotificationEvent event, Function(String) onLog) async {
    final pkg = event.packageName ?? '';
    
    // Log all notifications for debugging
    onLog('DEBUG: pkg=$pkg, title=${event.title}');
    
    if (pkg != 'id.co.bankbkemobile.digitalbank' && pkg != 'test.simulation') {
      return false; // Ignore non-seabank apps
    }

    final title = event.title ?? '';
    final content = event.content ?? '';
    final text = '$title $content'.toLowerCase();
    
    onLog('Received Notification: $content');

    TransactionModel? transaction = _parseNotification(text, content, title);

    if (transaction != null) {
      onLog('Parsed: ${transaction.type} - Rp ${transaction.amount}');
      try {
        await _repository.insertTransaction(transaction);
        onLog('Successfully inserted to Supabase');
        return true;
      } catch (e) {
        onLog('Supabase Error (Check RLS): $e');
        return false;
      }
    } else {
      onLog('Failed to parse or not a transaction notification.');
      return false;
    }
  }

  static TransactionModel? _parseNotification(String lowerText, String originalText, String title) {
    final lowerTitle = title.toLowerCase();
    
    // Determine type by title first, then fallback to content
    bool isIncome = lowerTitle.contains('masuk') || 
                    lowerTitle.contains('terima') ||
                    lowerText.contains('masuk') || 
                    lowerText.contains('dikreditkan') ||
                    lowerText.contains('terima dana') ||
                    lowerText.contains('dari ');
                    
    bool isExpense = lowerTitle.contains('keluar') || 
                     lowerTitle.contains('bayar') ||
                     lowerTitle.contains('pembayaran') ||
                     lowerText.contains('keluar') || 
                     lowerText.contains('qris') || 
                     lowerText.contains('bayar') ||
                     lowerText.contains('transfer ke') ||
                     lowerText.contains('didebit');

    // If both match or neither match, we make a best guess.
    // Usually 'ke' vs 'dari' is a good indicator.
    if (isIncome == isExpense) {
      if (lowerText.contains('dari ')) {
        isIncome = true;
        isExpense = false;
      } else if (lowerText.contains('ke ') || lowerText.contains('qris')) {
        isExpense = true;
        isIncome = false;
      } else {
        // Default fallback if we can extract an amount
        isExpense = true; 
      }
    }

    final amount = _extractAmount(originalText);
    if (amount != null) {
      if (isIncome) {
        return TransactionModel(
          title: 'SeaBank Masuk',
          amount: amount,
          type: 'income',
        );
      } else {
        return TransactionModel(
          title: 'SeaBank Keluar / QRIS',
          amount: amount,
          type: 'expense',
        );
      }
    }

    return null;
  }

  static double? _extractAmount(String text) {
    // Matches "Rp50.000", "Rp 50.000", "Rp 50,000", "IDR 50.000", "50.000" etc.
    // Let's look for Rp or IDR optionally, followed by digits and dots/commas.
    final RegExp regex = RegExp(r'(?:Rp|IDR)\s?([0-9\.\,]+)', caseSensitive: false);
    var match = regex.firstMatch(text);

    String? amountStr;
    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    } else {
      // If Rp/IDR is missing, just try to find a typical money number (e.g. 50.000)
      // Look for a number with at least one dot or comma that has 3 digits after it
      final RegExp fallbackRegex = RegExp(r'\b([0-9]{1,3}(?:\.[0-9]{3})+)\b');
      final fallbackMatch = fallbackRegex.firstMatch(text);
      if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
        amountStr = fallbackMatch.group(1);
      }
    }

    if (amountStr != null) {
      // Remove all dots and commas except the last one if it's a decimal (rare in IDR but possible)
      amountStr = amountStr.replaceAll('.', '').replaceAll(',', '');
      return double.tryParse(amountStr);
    }
    return null;
  }
}
