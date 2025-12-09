// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/tariff.dart';
import '../models/ticket.dart';
import '../services/storage.dart';
import 'tariff_editor.dart';
import 'ticket_editor.dart';
import 'sold_tickets_screen.dart';

enum SortMode { none, destinationAsc, priceAsc, priceDesc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Tariff> _tariffs = [];
  List<Ticket> _tickets = [];
  SortMode _sort = SortMode.none;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final data = await StorageService.loadInitialData();
      if (!mounted) return;
      setState(() {
        _tariffs = List<Tariff>.from(data['tariffs'] as List<Tariff>);
        _tickets = List<Ticket>.from(data['tickets'] as List<Ticket>);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось загрузить данные: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTariff() async {
    final res = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TariffEditor.add()));
    if (res is Tariff) {
      setState(() => _tariffs.add(res));
      try {
        await StorageService.saveTariffToStorage(res);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Тариф добавлен локально, но не сохранён в БД: $e')));
      }
    }
  }

  Future<void> _editTariff(int index) async {
    final t = _tariffs[index];
    final res = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TariffEditor.edit(t)));
    if (res is Tariff) {
      setState(() => _tariffs[index] = res);
      try {
        await StorageService.saveTariffToStorage(res);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Изменения сохранены локально, но не в БД: $e')));
      }
    }
  }

  void _viewTariff(int index) {
    final t = _tariffs[index];
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TariffEditor.view(t)));
  }

  void _deleteTariff(int index) {
    setState(() => _tariffs.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тариф удалён (локально).')));
  }

  Future<void> _sellTicket() async {
    if (_tariffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала добавьте тарифы')));
      return;
    }
    final ticket = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketEditor(tariffs: _tariffs)));
    if (ticket is Ticket) {
      setState(() => _tickets.add(ticket));
      try {
        await StorageService.saveTicketToStorage(ticket);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Билет сохранён локально, но не в БД: $e')));
      }
    }
  }

  void _viewSoldTickets() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SoldTicketsScreen(tickets: _tickets)));
  }

  void _sortList(SortMode mode) {
    setState(() {
      _sort = mode;
      if (mode == SortMode.destinationAsc) {
        _tariffs.sort((a, b) => a.destination.compareTo(b.destination));
      } else if (mode == SortMode.priceAsc) {
        _tariffs.sort((a, b) => a.price.compareTo(b.price));
      } else if (mode == SortMode.priceDesc) {
        _tariffs.sort((a, b) => b.price.compareTo(a.price));
      }
    });
  }

  Future<void> _import() async {
    try {
      final map = await StorageService.importAll();
      final importedTariffs = map['tariffs'] as List<Tariff>;
      final importedTickets = map['tickets'] as List<Ticket>;
      if (importedTariffs.isNotEmpty || importedTickets.isNotEmpty) {
        setState(() {
          _tariffs.addAll(importedTariffs);
          _tickets.addAll(importedTickets);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Импорт завершён')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл пуст или не содержит данных')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    }
  }

  Future<void> _export() async {
    try {
      await StorageService.exportAll(_tariffs, _tickets);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Экспорт завершён')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  Tariff? _findCheapest() {
    if (_tariffs.isEmpty) return null;
    return _tariffs.reduce((a, b) {
      final pa = a is DiscountedTariff
          ? (a as DiscountedTariff).finalPrice()
          : a.price;
      final pb = b is DiscountedTariff
          ? (b as DiscountedTariff).finalPrice()
          : b.price;
      return pa < pb ? a : b;
    });
  }

  List<Tariff> _searchByDestination(String dest) {
    return _tariffs
        .where((t) => t.destination.toLowerCase().contains(dest.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool dbMode = StorageService.useDb;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Система управления тарифами'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  dbMode ? Icons.storage : Icons.cloud_off,
                  size: 14,
                  color:
                      dbMode ? Colors.greenAccent[400] : Colors.redAccent[400],
                ),
                const SizedBox(width: 6),
                Text(
                  dbMode ? 'Режим: база данных' : 'Режим: локальный',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            )
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _export),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _import),
          PopupMenuButton<SortMode>(
            onSelected: _sortList,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  child: Text('По направлению (A-Z)'),
                  value: SortMode.destinationAsc),
              PopupMenuItem(
                  child: Text('По цене (возр.)'), value: SortMode.priceAsc),
              PopupMenuItem(
                  child: Text('По цене (убыв.)'), value: SortMode.priceDesc),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
              heroTag: 'addTariff',
              child: const Icon(Icons.add),
              onPressed: _addTariff),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: 'sellTicket',
              child: const Icon(Icons.confirmation_number),
              onPressed: _sellTicket),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Блок кнопок управления
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final cheapest = _findCheapest();
                            final msg = cheapest == null
                                ? 'Список пуст'
                                : 'Самый дешёвый: ${cheapest.destination} — ${cheapest is DiscountedTariff ? (cheapest as DiscountedTariff).finalPrice().toStringAsFixed(2) : cheapest.price.toStringAsFixed(2)}';
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                      content: Text(msg),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('OK'))
                                      ],
                                    ));
                          },
                          child: const Text('Найти самый дешёвый'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await StorageService.connectDb();
                            setState(() {});
                          },
                          child: const Text('Подключить БД'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await StorageService.disconnectDb();
                            setState(() {});
                          },
                          child: const Text('Отключить БД'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final ctl = TextEditingController();
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                      title: const Text('Поиск по направлению'),
                                      content: TextField(controller: ctl),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              final res = _searchByDestination(
                                                  ctl.text);
                                              Navigator.of(context).pop();
                                              showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                        title: const Text(
                                                            'Результат'),
                                                        content: Text(res
                                                                .isEmpty
                                                            ? 'Не найдено'
                                                            : res
                                                                .map((e) =>
                                                                    '${e.destination} — ${e is DiscountedTariff ? (e as DiscountedTariff).finalPrice().toStringAsFixed(2) : e.price.toStringAsFixed(2)}')
                                                                .join('\n')),
                                                        actions: [
                                                          TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context),
                                                              child: const Text(
                                                                  'OK'))
                                                        ],
                                                      ));
                                            },
                                            child: const Text('Найти')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Отмена')),
                                      ],
                                    ));
                          },
                          child: const Text('Поиск'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                            onPressed: _viewSoldTickets,
                            child: const Text('Проданные билеты')),
                        const SizedBox(width: 8),
                        Text('Тарифов: ${_tariffs.length}'),
                        const SizedBox(width: 16),
                        Text('Билетов: ${_tickets.length}'),
                      ],
                    ),
                  ),
                ),
                // Таблица тарифов
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Направление')),
                        DataColumn(label: Text('Цена')),
                        DataColumn(label: Text('Тип')),
                        DataColumn(label: Text('Действия')),
                      ],
                      rows: List.generate(_tariffs.length, (i) {
                        final t = _tariffs[i];
                        final priceLabel = t is DiscountedTariff
                            ? (t as DiscountedTariff)
                                    .finalPrice()
                                    .toStringAsFixed(2) +
                                ' (с учётом скидки)'
                            : t.price.toStringAsFixed(2);
                        return DataRow(cells: [
                          DataCell(Text(t.destination)),
                          DataCell(Text(priceLabel)),
                          DataCell(Text(t is DiscountedTariff
                              ? 'Со скидкой'
                              : 'Обычный')),
                          DataCell(Row(children: [
                            IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () => _viewTariff(i)),
                            IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editTariff(i)),
                            IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteTariff(i)),
                          ])),
                        ]);
                      }),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
