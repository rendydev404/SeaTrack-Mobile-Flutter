import '../core/sources.dart';

enum TxType {
  income,
  expense;

  static TxType parse(String? v) => v == 'income' ? income : expense;
  String get key => this == income ? 'income' : 'expense';
  String get label => this == income ? 'Masuk' : 'Keluar';
}

class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final TxType type;
  final DateTime createdAt;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.createdAt,
  });

  bool get isIncome => type == TxType.income;

  /// Sumber (SeaBank/DANA/GoPay) diturunkan dari prefix judul agar skema DB
  /// tetap sederhana dan kompatibel dengan data yang sudah ada.
  TxSource get source => TxSource.fromTitle(title);

  /// Judul tanpa prefix sumber, untuk ditampilkan di daftar.
  String get description {
    final s = source;
    if (s == TxSource.manual) return title;
    var d = title.trimLeft().substring(s.label.length).trimLeft();
    while (d.isNotEmpty && _separators.contains(d[0])) {
      d = d.substring(1).trimLeft();
    }
    return d.isEmpty ? title : d;
  }

  static const _separators = {'·', '•', '-', ':', '|'};

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final raw = map['created_at'];
    return TransactionModel(
      id: (map['id'] as num?)?.toInt(),
      title: (map['title'] ?? '') as String,
      amount: double.tryParse(map['amount']?.toString() ?? '') ?? 0,
      type: TxType.parse(map['type'] as String?),
      createdAt: raw is String ? DateTime.parse(raw) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'type': type.key,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  TransactionModel copyWith({
    int? id,
    String? title,
    double? amount,
    TxType? type,
    DateTime? createdAt,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
      );
}
