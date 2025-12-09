// lib/services/database_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/tariff.dart';
import '../models/ticket.dart';
import '../models/passport.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late DatabaseFactory _dbFactory;
  Database? _db;
  String _dbPath = '';

  Future<void> init({String? filePath}) async {
    // инициализация FFI (важно для десктопа)
    sqfliteFfiInit();
    _dbFactory = databaseFactoryFfi;

    // определяем путь к файлу БД (в текущей рабочей директории)
    final dbFile = filePath ?? p.join(Directory.current.path, 'station.db');
    _dbPath = dbFile;

    try {
      _db = await _dbFactory.openDatabase(dbFile,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await _createTables(db);
            },
          ));
      // если таблицы не существуют (редкие случаи) — создаём
      await _createTables(_db!);
    } catch (e) {
      // пробрасываем вверх — вызывающий обработает (режим локально)
      rethrow;
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tariffs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination TEXT NOT NULL,
        price REAL NOT NULL,
        is_discount INTEGER NOT NULL DEFAULT 0,
        discount_percent REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS passports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        series TEXT NOT NULL,
        number TEXT NOT NULL,
        full_name TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tickets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passport_id INTEGER NOT NULL,
        tariff_id INTEGER NOT NULL,
        purchase_date TEXT NOT NULL,
        FOREIGN KEY(passport_id) REFERENCES passports(id),
        FOREIGN KEY(tariff_id) REFERENCES tariffs(id)
      );
    ''');
  }

  // ----- Tariff CRUD -----
  Future<int> insertTariff(Tariff t) async {
    final db = _db!;
    final map = {
      'destination': t.destination,
      'price': t.price,
      'is_discount': t is DiscountedTariff ? 1 : 0,
      'discount_percent': t is DiscountedTariff
          ? (t as DiscountedTariff).discountPercent
          : null,
    };
    return await db.insert('tariffs', map);
  }

  Future<List<Tariff>> getAllTariffs() async {
    final db = _db!;
    final rows = await db.query('tariffs');
    return rows.map((r) {
      final isDiscount = (r['is_discount'] as int) == 1;
      if (isDiscount) {
        return DiscountedTariff(
          destination: r['destination'] as String,
          price: (r['price'] as num).toDouble(),
          discountPercent: (r['discount_percent'] as num).toDouble(),
        );
      } else {
        return Tariff(
          destination: r['destination'] as String,
          price: (r['price'] as num).toDouble(),
        );
      }
    }).toList();
  }

  Future<void> updateTariff(int id, Tariff t) async {
    final db = _db!;
    await db.update(
        'tariffs',
        {
          'destination': t.destination,
          'price': t.price,
          'is_discount': t is DiscountedTariff ? 1 : 0,
          'discount_percent': t is DiscountedTariff
              ? (t as DiscountedTariff).discountPercent
              : null,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> deleteTariff(int id) async {
    final db = _db!;
    await db.delete('tariffs', where: 'id = ?', whereArgs: [id]);
  }

  // ----- Passport & Ticket -----
  Future<int> insertPassport(Passport p) async {
    final db = _db!;
    final map = {
      'series': p.series,
      'number': p.number,
      'full_name': p.fullName,
    };
    return await db.insert('passports', map);
  }

  Future<int> insertTicket(Ticket t) async {
    final db = _db!;
    // ensure passport exists (insert and get id)
    final passportId = await insertPassport(t.passenger);
    // we need tariff id - for simplicity: try to find matching tariff by destination+price
    final tariffRow = await db.query('tariffs',
        where: 'destination = ? AND price = ?',
        whereArgs: [t.tariff.destination, t.tariff.price],
        limit: 1);
    int tariffId;
    if (tariffRow.isEmpty) {
      // insert tariff
      tariffId = await insertTariff(t.tariff);
    } else {
      tariffId = tariffRow.first['id'] as int;
    }

    final map = {
      'passport_id': passportId,
      'tariff_id': tariffId,
      'purchase_date': t.purchaseDate,
    };
    return await db.insert('tickets', map);
  }

  Future<List<Ticket>> getAllTickets() async {
    final db = _db!;
    final rows = await db.rawQuery('''
      SELECT tickets.id as tid, tickets.purchase_date, 
             passports.series, passports.number, passports.full_name,
             tariffs.destination as dest, tariffs.price as price, tariffs.is_discount, tariffs.discount_percent
      FROM tickets
      JOIN passports ON tickets.passport_id = passports.id
      JOIN tariffs ON tickets.tariff_id = tariffs.id
      ORDER BY tickets.id ASC
    ''');

    return rows.map((r) {
      final passport = Passport(
        series: r['series'] as String,
        number: r['number'] as String,
        fullName: r['full_name'] as String,
      );
      final isDiscount = (r['is_discount'] as int) == 1;
      final tariff = isDiscount
          ? DiscountedTariff(
              destination: r['dest'] as String,
              price: (r['price'] as num).toDouble(),
              discountPercent: (r['discount_percent'] as num).toDouble(),
            )
          : Tariff(
              destination: r['dest'] as String,
              price: (r['price'] as num).toDouble(),
            );
      return Ticket(
          passenger: passport,
          tariff: tariff,
          purchaseDate: r['purchase_date'] as String);
    }).toList();
  }

  // ----- Export DB -> JSON file -----
  Future<void> exportDbToFile(String path) async {
    final tariffs = await getAllTariffs();
    final tickets = await getAllTickets();
    final map = {
      'tariffs': tariffs.map((t) => t.toJson()).toList(),
      'tickets': tickets.map((tk) => tk.toJson()).toList(),
    };
    final file = File(path);
    await file.writeAsString(jsonEncode(map), flush: true);
  }

  // ----- Import JSON file -> DB (вставляет записи) -----
  Future<void> importFileToDb(String path) async {
    final file = File(path);
    if (!file.existsSync()) throw Exception('Файл не найден');
    final content = await file.readAsString();
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    // Есть tariffs
    if (parsed['tariffs'] != null) {
      for (var e in parsed['tariffs'] as List) {
        final m = Map<String, dynamic>.from(e as Map);
        Tariff t;
        if (m['type'] == 'discount') {
          t = DiscountedTariff.fromJson(m);
        } else {
          t = Tariff.fromJson(m);
        }
        await insertTariff(t);
      }
    }

    // Есть tickets
    if (parsed['tickets'] != null) {
      for (var e in parsed['tickets'] as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final ticket = Ticket.fromJson(m);
        await insertTicket(ticket);
      }
    }
  }

  // helper: check if DB initialized
  bool get isInitialized => _db != null;
}
