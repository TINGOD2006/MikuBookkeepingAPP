import 'dart:convert';

class Record {
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final DateTime createdAt;
  final String id; // 不允許 null

  Record({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    DateTime? createdAt,
    String? id, // 可選參數
  })  : createdAt = createdAt ?? DateTime.now(),
        id = id ?? DateTime.now().millisecondsSinceEpoch.toString(); //自動產生唯一 ID

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'id': id, // 儲存 ID
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory Record.fromJson(Map<String, dynamic> map) {
    return Record(
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  String get formattedDate {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime {
    return '$formattedDate $formattedTime';
  }
}