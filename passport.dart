// lib/models/passport.dart
class Passport {
  String series; // 4 digits
  String number; // 6 digits
  String fullName;

  Passport(
      {required this.series, required this.number, required this.fullName}) {
    _validateSeries();
    _validateNumber();
    _validateName();
  }

  void _validateSeries() {
    if (series.length != 4 || !_isDigitsOnly(series)) {
      throw ArgumentError('Серия паспорта должна содержать 4 цифры');
    }
  }

  void _validateNumber() {
    if (number.length != 6 || !_isDigitsOnly(number)) {
      throw ArgumentError('Номер паспорта должен содержать 6 цифр');
    }
  }

  void _validateName() {
    if (fullName.trim().isEmpty) {
      throw ArgumentError('ФИО не может быть пустым');
    }
    final allowed = RegExp(r'^[\p{L}\s\-]+$', unicode: true);
    if (!allowed.hasMatch(fullName)) {
      throw ArgumentError('ФИО содержит недопустимые символы');
    }
  }

  static bool _isDigitsOnly(String s) => RegExp(r'^\d+$').hasMatch(s);

  Map<String, dynamic> toJson() => {
        'series': series,
        'number': number,
        'fullName': fullName,
      };

  factory Passport.fromJson(Map<String, dynamic> j) => Passport(
        series: j['series'] as String,
        number: j['number'] as String,
        fullName: j['fullName'] as String,
      );
}
