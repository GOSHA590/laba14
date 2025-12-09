// lib/screens/sold_tickets_screen.dart
import 'package:flutter/material.dart';
import '../models/ticket.dart';

class SoldTicketsScreen extends StatelessWidget {
  final List<Ticket> tickets;
  const SoldTicketsScreen({required this.tickets, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Проданные билеты')),
      body: tickets.isEmpty
          ? const Center(child: Text('Проданных билетов нет'))
          : ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (context, i) {
                final t = tickets[i];
                final passenger = t.passenger.fullName;
                final dest = t.tariff.destination;
                final price = t.getPrice().toStringAsFixed(2);
                final date = t.purchaseDate;
                return ListTile(
                  title: Text('$passenger → $dest'),
                  subtitle: Text('Дата: $date'),
                  trailing: Text('$price ₽'),
                  onTap: () {
                    // показываем детали
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Билет #${i + 1}'),
                        content: Text('Пассажир: $passenger\n'
                            'Паспорт: ${t.passenger.series} ${t.passenger.number}\n'
                            'Направление: $dest\n'
                            'Цена: $price ₽\n'
                            'Дата: $date'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'))
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
