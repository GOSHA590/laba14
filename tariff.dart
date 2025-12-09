// lib/models/tariff.dart
class Tariff {
  String destination;
  double price;

  Tariff({required this.destination, required this.price}) {
    _validate();
  }

  void _validate() {
    if (destination.trim().isEmpty) {
      throw ArgumentError('Название направления не может быть пустым');
    }
    final forbidden = RegExp('я');
    if (forbidden.hasMatch(destination)) {
      throw ArgumentError('Название направления содержит запрещенные символы');
    }
    if (price <= 0) {
      throw ArgumentError('Цена должна быть положительной');
    }
  }

  Map<String, dynamic> toJson() => {
        'type': 'normal',
        'destination': destination,
        'price': price,
      };

  factory Tariff.fromJson(Map<String, dynamic> j) => Tariff(
      destination: j['destination'] as String,
      price: (j['price'] as num).toDouble());
}

class DiscountedTariff extends Tariff {
  double discountPercent; // 0..100

  DiscountedTariff({
    required String destination,
    required double price,
    required this.discountPercent,
  }) : super(destination: destination, price: price) {
    _validateDiscount();
  }

  void _validateDiscount() {
    if (discountPercent < 0 || discountPercent > 100) {
      throw ArgumentError('Скидка должна быть между 0 и 100');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'discount',
        'destination': destination,
        'price': price,
        'discountPercent': discountPercent,
      };

  factory DiscountedTariff.fromJson(Map<String, dynamic> j) => DiscountedTariff(
        destination: j['destination'] as String,
        price: (j['price'] as num).toDouble(),
        discountPercent: (j['discountPercent'] as num).toDouble(),
      );

  double finalPrice() => price * (1 - discountPercent / 100.0);
}
