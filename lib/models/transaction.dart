class TransactionModel {
  final String title;
  final double amount;
  final String type;

  TransactionModel({
    required this.title,
    required this.amount,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type,
    };
  }
}
