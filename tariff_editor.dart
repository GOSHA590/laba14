// lib/screens/tariff_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tariff.dart';

enum EditorMode { add, edit, view }

class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;
  final RegExp _allowed = RegExp(r'[0-9.,]');

  DecimalTextInputFormatter({required this.decimalRange})
      : assert(decimalRange >= 0);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final String newText = newValue.text;

    if (newText.isEmpty) return newValue;
    for (var ch in newText.split('')) {
      if (!_allowed.hasMatch(ch)) {
        return oldValue;
      }
    }
    if (newText.contains('-')) return oldValue;
    final sepMatches = RegExp(r'[.,]').allMatches(newText).length;
    if (sepMatches > 1) return oldValue;
    if (sepMatches == 1) {
      final parts = newText.split(RegExp(r'[.,]'));
      final frac = parts.length > 1 ? parts[1] : '';
      if (frac.length > decimalRange) return oldValue;
    }
    return newValue;
  }
}

class TariffEditor extends StatefulWidget {
  final EditorMode mode;
  final Tariff? tariff;

  TariffEditor.add()
      : mode = EditorMode.add,
        tariff = null;

  TariffEditor.edit(Tariff t)
      : mode = EditorMode.edit,
        tariff = t;

  TariffEditor.view(Tariff t)
      : mode = EditorMode.view,
        tariff = t;

  @override
  _TariffEditorState createState() => _TariffEditorState();
}

class _TariffEditorState extends State<TariffEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _destController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  bool isDiscount = false;

  // корректная маска запрещённых символов
  final RegExp _forbiddenDestination =
      RegExp("!@#%^&*()+=[]{}|;:,.<>?/\\\"'~`");

  @override
  void initState() {
    super.initState();
    _destController =
        TextEditingController(text: widget.tariff?.destination ?? '');
    _priceController =
        TextEditingController(text: widget.tariff?.price.toString() ?? '');
    if (widget.tariff is DiscountedTariff) {
      _discountController = TextEditingController(
          text: (widget.tariff as DiscountedTariff)
              .discountPercent
              .toInt()
              .toString());
      isDiscount = true;
    } else {
      _discountController = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _destController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readonly = widget.mode == EditorMode.view;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == EditorMode.add
              ? 'Добавить тариф'
              : widget.mode == EditorMode.edit
                  ? 'Редактировать тариф'
                  : 'Просмотр тарифа',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _destController,
                decoration: const InputDecoration(
                  labelText: 'Направление',
                  helperText: 'Без спецсимволов: ! @ # % ^ & * и т.п.',
                ),
                readOnly: readonly,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Нужно ввести направление';
                  }
                  if (_forbiddenDestination.hasMatch(v)) {
                    return 'Недопустимые символы';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Цена (руб.)',
                  helperText:
                      'Минимум: 1. Максимум: 1 000 000. Допускается до 1 знака после запятой.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  DecimalTextInputFormatter(decimalRange: 1),
                ],
                readOnly: readonly,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите цену';
                  final normalized = v.replaceAll(',', '.').trim();
                  if (!RegExp(r'^\d+([.]\d)?$').hasMatch(normalized)) {
                    return 'Только числа. Максимум 1 знак после запятой';
                  }
                  final val = double.tryParse(normalized);
                  if (val == null) return 'Введите корректное число';
                  if (val < 1) return 'Минимальная цена — 1';
                  if (val > 1000000) return 'Цена не может превышать 1 000 000';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Со скидкой'),
                value: isDiscount,
                onChanged:
                    readonly ? null : (val) => setState(() => isDiscount = val),
              ),
              if (isDiscount)
                TextFormField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'Скидка (%)',
                    helperText: 'Только целое число от 0 до 100',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  readOnly: readonly,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Введите процент';
                    }
                    final val = int.tryParse(v.trim());
                    if (val == null) return 'Введите целое число';
                    if (val < 0 || val > 100) {
                      return 'Процент должен быть от 0 до 100';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),
              if (!readonly)
                ElevatedButton(
                  child: Text(
                      widget.mode == EditorMode.add ? 'Добавить' : 'Сохранить'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final dest = _destController.text.trim();
                      final price = double.parse(
                        _priceController.text.replaceAll(',', '.').trim(),
                      );

                      final result = isDiscount
                          ? DiscountedTariff(
                              destination: dest,
                              price: price,
                              discountPercent:
                                  int.parse(_discountController.text.trim())
                                      .toDouble(),
                            )
                          : Tariff(destination: dest, price: price);

                      Navigator.of(context).pop(result);
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
