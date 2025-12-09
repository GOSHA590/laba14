// lib/models/ticket.dart
import 'passport.dart';
import 'tariff.dart';

class Ticket {
  Passport passenger;
  Tariff tariff;
  String purchaseDate; // свободный формат, можно хранить ISO

  Ticket({
    required this.passenger,
    required this.tariff,
    required this.purchaseDate,
  });

  double getPrice() {
    if (tariff is DiscountedTariff) {
      return (tariff as DiscountedTariff).finalPrice();
    }
    return tariff.price;
  }

  Map<String, dynamic> toJson() => {
        'passenger': passenger.toJson(),
        'tariff': tariff.toJson(),
        'purchaseDate': purchaseDate,
      };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        passenger: Passport.fromJson(
          Map<String, dynamic>.from(j['passenger'] as Map),
        ),
        tariff: (j['tariff'] as Map)['type'] == 'discount'
            ? DiscountedTariff.fromJson(
                Map<String, dynamic>.from(j['tariff'] as Map),
              )
            : Tariff.fromJson(Map<String, dynamic>.from(j['tariff'] as Map)),
        purchaseDate: j['purchaseDate'] as String,
      );
}
