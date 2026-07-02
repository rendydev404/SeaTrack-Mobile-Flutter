import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';

class SupabaseService {
  // TODO: Replace with actual Supabase URL and Anon Key
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static Future<void> insertTransaction(TransactionModel transaction) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('transactions').insert(transaction.toMap());
      print('Transaction synced to Supabase successfully.');
    } catch (e) {
      print('Error syncing to Supabase: $e');
    }
  }
}
