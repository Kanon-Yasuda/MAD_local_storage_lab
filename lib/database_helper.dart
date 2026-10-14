import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _db;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _databaseName);

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createGuestTable(db);
        await _createCatalogueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCatalogueTables(db);
        }
      },
    );
  }

  Future<void> _createGuestTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCatalogueTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES folders(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cards_folder_id
      ON cards(folder_id)
    ''');
  }

  // Guest operations: preserve Part I functionality.

  Future<int> insert(Map<String, dynamic> row) {
    return _db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() {
    return _db.query(table);
  }

  Future<int> queryRowCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM $table',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) {
    final id = row[columnId] as int;
    return _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) {
    return _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Folder operations.

  Future<List<Map<String, dynamic>>> queryFolders() {
    return _db.rawQuery('''
      SELECT f.*,
        (SELECT COUNT(*) FROM cards c
         WHERE c.folder_id = f.id) AS card_count
      FROM folders f
      ORDER BY f.id
    ''');
  }

  Future<int> insertFolder(String name) {
    return _db.insert('folders', {
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> deleteFolder(int id) {
    return _db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Card operations.

  Future<List<Map<String, dynamic>>> queryCards(int folderId) {
    return _db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'id',
    );
  }

  Future<int> insertCard(Map<String, dynamic> card) {
    return _db.insert('cards', card);
  }

  Future<int> updateCard(int id, Map<String, dynamic> card) {
    return _db.update(
      'cards',
      card,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCard(int id) {
    return _db.delete(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countCards(int folderId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM cards WHERE folder_id = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    await _db.close();
  }
}