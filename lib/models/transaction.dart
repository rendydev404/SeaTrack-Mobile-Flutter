class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type;
  final DateTime? createdAt;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] != null ? map['id'] as int : null,
      title: map['title'] ?? '',
      amount: map['amount'] != null ? double.parse(map['amount'].toString()) : 0.0,
      type: map['type'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
