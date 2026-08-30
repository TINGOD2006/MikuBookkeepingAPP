import 'dart:convert';

class Record {
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  Record({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory Record.fromJson(Map<String, dynamic> map) {
    return Record(
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}