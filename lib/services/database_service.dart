import 'package:sqflite/sqflite.dart';

/// Database SQLite lokal. Satu file di penyimpanan internal aplikasi,
/// tidak ada server dan tidak ada data yang keluar dari perangkat.
class DatabaseService {
  DatabaseService._();

  static const fileName = 'seatrack.db';
  static const table = 'transactions';
  static const _version = 1;

  static Database? _db;
  static String? _path;

  static Database get instance {
    final db = _db;
    if (db == null) {
      throw StateError('Database belum dibuka. Panggil DatabaseService.open().');
    }
    return db;
  }

  static bool get isReady => _db != null;

  /// Lokasi file database, untuk ditampilkan di layar pengaturan.
  static String get path => _path ?? '';

  static Future<void> open() async {
    if (_db != null) return;
    final dir = await getDatabasesPath();
    final file = '$dir/$fileName';
    _db = await openDatabase(
      file,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL CHECK (amount > 0),
            type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX ${table}_created_at_idx ON $table (created_at DESC)',
        );
      },
    );
    _path = file;
  }

  /// Ukuran database dalam byte, 0 bila belum ada isinya.
  static Future<int> sizeInBytes() async {
    final db = _db;
    if (db == null) return 0;
    final rows = await db.rawQuery(
      'SELECT page_count * page_size AS bytes FROM pragma_page_count(), pragma_page_size()',
    );
    return (rows.first['bytes'] as num?)?.toInt() ?? 0;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
