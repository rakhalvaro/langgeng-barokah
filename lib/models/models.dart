class DailyStock {
  String id;
  DateTime date;
  double morningKg;
  double afternoonKg;
  double previousLeftover;
  String? notes;

  DailyStock({
    required this.id,
    required this.date,
    required this.morningKg,
    required this.afternoonKg,
    required this.previousLeftover,
    this.notes,
  });

  double get totalIn => morningKg + afternoonKg;
  double get totalAvailable => totalIn + previousLeftover;

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'morningKg': morningKg,
      'afternoonKg': afternoonKg,
      'previousLeftover': previousLeftover,
      'notes': notes,
    };
  }

  factory DailyStock.fromMap(String id, Map<String, dynamic> map) {
    return DailyStock(
      id: id,
      date: DateTime.parse(map['date']),
      morningKg: (map['morningKg'] ?? 0).toDouble(),
      afternoonKg: (map['afternoonKg'] ?? 0).toDouble(),
      previousLeftover: (map['previousLeftover'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }
}

class EggOrder {
  String id;
  String buyerName;
  double kg;
  double pricePerKg;
  double total;
  bool isPaid;
  DateTime dateTime;

  EggOrder({
    required this.id,
    required this.buyerName,
    required this.kg,
    required this.pricePerKg,
    required this.total,
    required this.isPaid,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'buyerName': buyerName,
      'kg': kg,
      'pricePerKg': pricePerKg,
      'total': total,
      'isPaid': isPaid,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory EggOrder.fromMap(String id, Map<String, dynamic> map) {
    return EggOrder(
      id: id,
      buyerName: map['buyerName'] ?? '',
      kg: (map['kg'] ?? 0).toDouble(),
      pricePerKg: (map['pricePerKg'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      isPaid: map['isPaid'] ?? false,
      dateTime: DateTime.parse(map['dateTime']),
    );
  }
}

class Expense {
  String id;
  String category;
  String description;
  double amount;
  DateTime dateTime;
 
  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.dateTime,
  });
 
  Map<String, dynamic> toMap() => {
        'category': category,
        'description': description,
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
      };
 
  factory Expense.fromMap(String id, Map<String, dynamic> map) => Expense(
        id: id,
        category: map['category'] ?? 'lainnya',
        description: map['description'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        dateTime: DateTime.parse(map['dateTime']),
      );
}