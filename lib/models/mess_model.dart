import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner }

class MessMenuItem {
  final String id;
  final String name;
  final String description;
  final MealType type;
  final double price;
  final bool isAvailable;
  final String? imageUrl;
  final Map<String, bool>? allergens;
  final Map<String, dynamic>? nutritionInfo;

  MessMenuItem({
    String? id,
    required this.name,
    this.description = '',
    required this.type,
    required this.price,
    this.isAvailable = true,
    this.imageUrl,
    this.allergens,
    this.nutritionInfo,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  MessMenuItem copyWith({
    String? id,
    String? name,
    String? description,
    MealType? type,
    double? price,
    bool? isAvailable,
    String? imageUrl,
    Map<String, bool>? allergens,
    Map<String, dynamic>? nutritionInfo,
  }) {
    return MessMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      allergens: allergens ?? this.allergens,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
    );
  }

  factory MessMenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessMenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: MealType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => MealType.lunch,
      ),
      price: (data['price'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      imageUrl: data['imageUrl'],
      allergens: data['allergens'] != null
          ? Map<String, bool>.from(data['allergens'])
          : null,
      nutritionInfo: data['nutritionInfo'],
    );
  }

  factory MessMenuItem.fromMap(Map<String, dynamic> data, [String? id]) {
    return MessMenuItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: MealType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => MealType.lunch,
      ),
      price: (data['price'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      imageUrl: data['imageUrl'],
      allergens: data['allergens'] != null
          ? Map<String, bool>.from(data['allergens'])
          : null,
      nutritionInfo: data['nutritionInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.toString(),
      'price': price,
      'isAvailable': isAvailable,
      'imageUrl': imageUrl,
      'allergens': allergens,
      'nutritionInfo': nutritionInfo,
    };
  }
}

class MessMenu {
  final String id;
  final DateTime date;
  final Map<MealType, List<MessMenuItem>> meals;
  final bool isActive;

  MessMenu({
    String? id,
    required this.date,
    required this.meals,
    this.isActive = true,
  }) : id = id ?? date.toIso8601String().split('T')[0];

  factory MessMenu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<MealType, List<MessMenuItem>> meals = {};
    for (final type in MealType.values) {
      final mealData = data[type.toString()] as List<dynamic>?;
      if (mealData != null) {
        meals[type] = mealData
            .map((item) => MessMenuItem.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    }

    return MessMenu(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meals: meals,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'isActive': isActive,
      ...meals.map((type, items) => MapEntry(
            type.toString(),
            items.map((item) => item.toMap()).toList(),
          )),
    };
  }
}
