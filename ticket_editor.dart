// lib/screens/ticket_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/passport.dart';
import '../models/ticket.dart';
import '../models/tariff.dart';

class DateInputFormatter extends TextInputFormatter {
  // Форматирует ввод в DD.MM.YYYY, позволяет только цифры и точки, автоматически ставит точки
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    // разрешаем только цифры и точки
    if (!RegExp(r'^[0-9.]*$').hasMatch(text)) return oldValue;
    // ограничим длину до 10 (DD.MM.YYYY)
    if (text.length > 10) return oldValue;

    // автопоставление точек
    String digits = text.replaceAll('.', '');
    StringBuffer buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      buf.write(digits[i]);
      if (i == 1 || i == 3) buf.write('.');
    }
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.toString().length),
    );
  }
}

class TicketEditor extends StatefulWidget {
  final List<Tariff> tariffs;
  TicketEditor({required this.tariffs});

  @override
  _TicketEditorState createState() => _TicketEditorState();
}

class _TicketEditorState extends State<TicketEditor> {
  final _formKey = GlobalKey<FormState>();
  int _selectedTariffIndex = 0;
  final _seriesCtl = TextEditingController();
  final _numberCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _dateCtl = TextEditingController();

  @override
  void dispose() {
    _seriesCtl.dispose();
    _numberCtl.dispose();
    _nameCtl.dispose();
    _dateCtl.dispose();
    super.dispose();
  }

  String? _validateDate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введите дату';
    final parts = v.split('.');
    if (parts.length != 3) return 'Формат ДД.ММ.ГГГГ';
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return 'Неверная дата';
    if (day < 1 || day > 31) return 'День должен быть от 1 до 31';
    if (month < 1 || month > 12) return 'Месяц должен быть от 1 до 12';
    if (year < 1 || year > 2025) return 'Год должен быть от 1 до 2025';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Продать билет')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<int>(
                value: _selectedTariffIndex,
                items: List.generate(widget.tariffs.length, (i) {
                  final t = widget.tariffs[i];
                  final label =
                      '${t.destination} — ${t is DiscountedTariff ? (t as DiscountedTariff).finalPrice().toStringAsFixed(2) : t.price.toStringAsFixed(2)}';
                  return DropdownMenuItem(value: i, child: Text(label));
                }),
                onChanged: (v) => setState(() => _selectedTariffIndex = v ?? 0),
                decoration:
                    const InputDecoration(labelText: 'Выберите направление'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _seriesCtl,
                decoration: const InputDecoration(
                    labelText: 'Серия паспорта (4 цифры)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().length != 4) return 'Серия 4 цифры';
                  if (!RegExp(r'^\d{4}$').hasMatch(v.trim()))
                    return 'Только цифры';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numberCtl,
                decoration:
                    const InputDecoration(labelText: 'Номер паспорта (6 цифр)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().length != 6) return 'Номер 6 цифр';
                  if (!RegExp(r'^\d{6}$').hasMatch(v.trim()))
                    return 'Только цифры';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'ФИО'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите ФИО';
                  if (!RegExp(r'^[\p{L}\s\-]+$', unicode: true)
                      .hasMatch(v.trim())) return 'Недопустимые символы';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateCtl,
                decoration: const InputDecoration(
                  labelText: 'Дата покупки (ДД.ММ.ГГГГ)',
                  helperText:
                      'Пример: 21.05.2024 (Д 1..31, М 1..12, Г 1..2025)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                validator: _validateDate,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Продать'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final passport = Passport(
                        series: _seriesCtl.text.trim(),
                        number: _numberCtl.text.trim(),
                        fullName: _nameCtl.text.trim());
                    final tariff = widget.tariffs[_selectedTariffIndex];
                    final ticket = Ticket(
                        passenger: passport,
                        tariff: tariff,
                        purchaseDate: _dateCtl.text.trim());
                    Navigator.of(context).pop(ticket);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
