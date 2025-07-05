enum TransactionType {
  income,
  expense,
}

class Transaction {
  final int? id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String category;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  Transaction({
    this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    required this.date,
    required this.createdAt,
  });

  // Convert Transaction to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Create Transaction from Map (database retrieval)
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      amount: map['amount'] as double,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      category: map['category'] as String,
      description: map['description'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  // Create a copy of Transaction with updated fields
  Transaction copyWith({
    int? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? category,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Transaction{id: $id, userId: $userId, amount: $amount, type: $type, category: $category, description: $description, date: $date, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          amount == other.amount &&
          type == other.type &&
          category == other.category &&
          description == other.description &&
          date == other.date &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      amount.hashCode ^
      type.hashCode ^
      category.hashCode ^
      description.hashCode ^
      date.hashCode ^
      createdAt.hashCode;
}
