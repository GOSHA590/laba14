// lib/services/storage.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/tariff.dart';
import '../models/ticket.dart';
import 'database_service.dart';

class StorageService {
  static bool useDb = false; // флаг режима: БД или локальный
  static final DatabaseService _dbService = DatabaseService();

  /// Инициализация при старте приложения
  static Future<void> init() async {
    try {
      await _dbService.init();
      useDb = true;
    } catch (e) {
      useDb = false;
    }
  }

  /// Подключение базы данных вручную
  static Future<void> connectDb() async {
    if (!_dbService.isInitialized) {
      try {
        await _dbService.init();
        useDb = true;
      } catch (e) {
        useDb = false;
        throw Exception('Не удалось подключить БД: $e');
      }
    } else {
      useDb = true;
    }
  }

  /// Отключение базы данных вручную
  static Future<void> disconnectDb() async {
    if (_dbService.isInitialized) {
      await _dbService.close();
    }
    useDb = false;
  }

  /// Экспорт данных
  static Future<void> exportAll(
      List<Tariff> tariffs, List<Ticket> tickets) async {
    final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить данные', fileName: 'station_data.json');
    if (savePath == null) return;

    if (useDb && _dbService.isInitialized) {
      await _dbService.exportDbToFile(savePath);
      return;
    }

    final file = File(savePath);
    final map = {
      'tariffs': tariffs.map((t) => t.toJson()).toList(),
      'tickets': tickets.map((tk) => tk.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(map), flush: true);
  }

  /// Импорт данных
  static Future<Map<String, dynamic>> importAll() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Открыть данные');
    if (res == null || res.files.isEmpty)
      return {'tariffs': <Tariff>[], 'tickets': <Ticket>[]};

    final path = res.files.single.path!;

    if (useDb && _dbService.isInitialized) {
      await _dbService.importFileToDb(path);
      final tariffs = await _dbService.getAllTariffs();
      final tickets = await _dbService.getAllTickets();
      return {'tariffs': tariffs, 'tickets': tickets};
    } else {
      final file = File(path);
      final content = await file.readAsString();
      final parsed = jsonDecode(content) as Map<String, dynamic>;

      final tlist = <Tariff>[];
      final tks = <Ticket>[];

      if (parsed['tariffs'] != null) {
        for (var e in parsed['tariffs'] as List) {
          final m = Map<String, dynamic>.from(e as Map);
          if (m['type'] == 'discount') {
            tlist.add(DiscountedTariff.fromJson(m));
          } else {
            tlist.add(Tariff.fromJson(m));
          }
        }
      }

      if (parsed['tickets'] != null) {
        for (var e in parsed['tickets'] as List) {
          tks.add(Ticket.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }

      return {'tariffs': tlist, 'tickets': tks};
    }
  }

  /// Загрузка данных при старте приложения
  static Future<Map<String, dynamic>> loadInitialData() async {
    if (useDb && _dbService.isInitialized) {
      final tariffs = await _dbService.getAllTariffs();
      final tickets = await _dbService.getAllTickets();
      return {'tariffs': tariffs, 'tickets': tickets};
    } else {
      return {'tariffs': <Tariff>[], 'tickets': <Ticket>[]};
    }
  }

  /// Сохранение отдельного тарифа
  static Future<void> saveTariffToStorage(Tariff t) async {
    if (useDb && _dbService.isInitialized) {
      await _dbService.insertTariff(t);
    }
  }

  /// Сохранение отдельного билета
  static Future<void> saveTicketToStorage(Ticket ticket) async {
    if (useDb && _dbService.isInitialized) {
      await _dbService.insertTicket(ticket);
    }
  }
}
