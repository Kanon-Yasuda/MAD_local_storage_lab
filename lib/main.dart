import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalRepository();
  try {
    await repository.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not open local storage. Check the terminal output and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
    return;
  }
  runApp(LocalStorageApp(repository: repository));
}

// The repository is kept in this file so this assignment can be implemented
// by replacing main.dart only. It opens the same MyDatabase.db file used by
// DatabaseHelper and upgrades version 1 without deleting my_table or its rows.
class LocalRepository {
  static const String _databaseName = 'MyDatabase.db';
  static const int _databaseVersion = 2;
  static const String foldersTable = 'folders';
  static const String cardsTable = 'cards';
  late final Database _db;

  Future<void> init() async {
    final documents = await getApplicationDocumentsDirectory();
    final databasePath = p.join(documents.path, _databaseName);
    _db = await openDatabase(
      databasePath,
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

  Future<void> _createGuestTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.table} (
        ${DatabaseHelper.columnId} INTEGER PRIMARY KEY,
        ${DatabaseHelper.columnName} TEXT NOT NULL,
        ${DatabaseHelper.columnAge} INTEGER NOT NULL
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
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON cards(folder_id)',
    );
  }

  // Part I guest roster methods.
  Future<List<Map<String, dynamic>>> getGuests() => _db.query(
        DatabaseHelper.table,
        orderBy: '${DatabaseHelper.columnId} ASC',
      );

  Future<int> getGuestCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.table}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertGuest(String name, int age) => _db.insert(
        DatabaseHelper.table,
        {
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        },
      );

  Future<int> updateGuest(int id, String name, int age) => _db.update(
        DatabaseHelper.table,
        {
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        },
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

  Future<int> deleteGuest(int id) => _db.delete(
        DatabaseHelper.table,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

  // Part II folder/card repository methods.
  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT folders.id, folders.name, folders.created_at,
             COUNT(cards.id) AS card_count
      FROM folders
      LEFT JOIN cards ON cards.folder_id = folders.id
      GROUP BY folders.id, folders.name, folders.created_at
      ORDER BY folders.name COLLATE NOCASE ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<int> insertFolder(String name) => _db.insert(
        foldersTable,
        {
          'name': name.trim(),
          'created_at': DateTime.now().toIso8601String(),
        },
      );

  Future<int> deleteFolder(int id) => _db.delete(
        foldersTable,
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query(
      cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) => _db.insert(
        cardsTable,
        card.toMap(),
      );

  Future<int> updateCard(CardRecord card) => _db.update(
        cardsTable,
        card.toMap(),
        where: 'id = ?',
        whereArgs: [card.id],
      );

  Future<int> deleteCard(int id) => _db.delete(
        cardsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> close() => _db.close();
}

class Folder {
  final int id;
  final String name;
  final String createdAt;
  final int cardCount;

  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.cardCount,
  });

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: map['created_at'] as String,
        cardCount: (map['card_count'] as int?) ?? 0,
      );
}

class CardRecord {
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    required this.notes,
    required this.imageRef,
    required this.folderId,
  });

  factory CardRecord.fromMap(Map<String, dynamic> map) => CardRecord(
        id: map['id'] as int,
        title: map['title'] as String,
        suit: map['suit'] as String,
        notes: map['notes'] as String,
        imageRef: map['image_ref'] as String?,
        folderId: map['folder_id'] as int,
      );

  Map<String, Object?> toMap() => {
        'title': title.trim(),
        'suit': suit,
        'notes': notes.trim(),
        'image_ref': (imageRef == null || imageRef!.trim().isEmpty)
            ? null
            : imageRef!.trim(),
        'folder_id': folderId,
      };
}

class LocalStorageApp extends StatelessWidget {
  final LocalRepository repository;
  const LocalStorageApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Local Storage Lab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Local Storage Lab'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people_alt_outlined), text: 'Guests'),
                  Tab(icon: Icon(Icons.folder_outlined), text: 'Folders'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                GuestRosterScreen(repository: repository),
                FolderListScreen(repository: repository),
              ],
            ),
          ),
        ),
      );
}

class GuestRosterScreen extends StatefulWidget {
  final LocalRepository repository;
  const GuestRosterScreen({super.key, required this.repository});

  @override
  State<GuestRosterScreen> createState() => _GuestRosterScreenState();
}

class _GuestRosterScreenState extends State<GuestRosterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _editingId;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadGuests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.getGuests();
      final count = await widget.repository.getGuestCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not load guests: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load guests. Please refresh.';
      });
    }
  }

  String? _validateName(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : 'Enter a guest name.';

  String? _validateAge(String? value) {
    final age = int.tryParse((value ?? '').trim());
    if (age == null) return 'Age must be a whole number.';
    if (age < 0 || age > 130) return 'Age must be between 0 and 130.';
    return null;
  }

  Future<void> _saveGuest() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      if (_editingId == null) {
        final id = await widget.repository.insertGuest(name, age);
        if (!mounted) return;
        setState(() => _message = 'Guest saved with ID $id.');
      } else {
        final id = _editingId!;
        final affected = await widget.repository.updateGuest(id, name, age);
        if (!mounted) return;
        setState(() => _message = affected == 1
            ? 'Guest ID $id updated.'
            : 'Guest ID $id was not found.');
      }
      if (!mounted) return;
      setState(() {
        _editingId = null;
        _nameController.clear();
        _ageController.clear();
      });
      await _loadGuests();
    } catch (error, stackTrace) {
      debugPrint('Could not save guest: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not save the guest.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit(Map<String, dynamic> row) {
    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _message = 'Editing guest ID $_editingId.';
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _ageController.clear();
      _message = 'Edit cancelled. No changes were saved.';
    });
  }

  Future<void> _deleteGuest(Map<String, dynamic> row) async {
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete $name (ID $id)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      if (mounted) setState(() => _message = 'Deletion cancelled.');
      return;
    }
    try {
      final affected = await widget.repository.deleteGuest(id);
      if (!mounted) return;
      setState(() => _message = affected == 1
          ? 'Guest ID $id deleted.'
          : 'Guest ID $id was not found.');
      if (_editingId == id) _cancelEdit();
      await _loadGuests();
    } catch (error, stackTrace) {
      debugPrint('Could not delete guest: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not delete the guest.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fall Festival Roster',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Guest name',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ageController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (0–130)',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateAge,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveGuest,
                    child: Text(_editingId == null ? 'Add Guest' : 'Save Changes'),
                  ),
                ),
                if (_editingId != null)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _busy ? null : _cancelEdit,
                      child: const Text('Cancel Edit'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadGuests,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh guests'),
          ),
          if (_error != null) _Notice(text: _error!, isError: true),
          if (_message != null) _Notice(text: _message!),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Festival Guests', style: Theme.of(context).textTheme.titleLarge),
              Text('Count: $_count', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No festival guests yet.', textAlign: TextAlign.center),
            )
          else
            ..._rows.map((row) {
              final id = row[DatabaseHelper.columnId] as int;
              final name = row[DatabaseHelper.columnName] as String;
              final age = row[DatabaseHelper.columnAge] as int;
              return Card(
                child: ListTile(
                  title: Text('$name — age $age'),
                  subtitle: Text('ID: $id'),
                  isThreeLine: false,
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'edit') _startEdit(row);
                      if (action == 'delete') _deleteGuest(row);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
}

class FolderListScreen extends StatefulWidget {
  final LocalRepository repository;
  const FolderListScreen({super.key, required this.repository});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not load folders: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load folders. Try refreshing.';
      });
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. Atlas',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) {
      if (mounted) setState(() => _message = 'Folder creation cancelled.');
      return;
    }
    if (name.trim().isEmpty) {
      setState(() => _error = 'Folder name cannot be blank.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final id = await widget.repository.insertFolder(name);
      if (!mounted) return;
      setState(() => _message = 'Folder saved with ID $id.');
      await _loadFolders();
    } on DatabaseException catch (error, stackTrace) {
      debugPrint('Could not create folder: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = error.isUniqueConstraintError()
          ? 'That folder name already exists. Choose another name.'
          : 'Could not create the folder.');
    } catch (error, stackTrace) {
      debugPrint('Could not create folder: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not create the folder.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(Folder folder) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderDetailScreen(
          repository: widget.repository,
          folder: folder,
        ),
      ),
    );
    if (mounted) await _loadFolders();
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" and its ${folder.cardCount} card(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete folder'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      if (mounted) setState(() => _message = 'Folder deletion cancelled.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final affected = await widget.repository.deleteFolder(folder.id);
      if (!mounted) return;
      setState(() => _message = affected == 1
          ? 'Folder ID ${folder.id} deleted; its cards were removed too.'
          : 'Folder ID ${folder.id} was not found.');
      await _loadFolders();
    } catch (error, stackTrace) {
      debugPrint('Could not delete folder: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not delete the folder.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadFolders,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Card folders', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  IconButton(
                    tooltip: 'Refresh folders',
                    onPressed: _busy ? null : _loadFolders,
                    icon: const Icon(Icons.refresh),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Open a folder to manage its cards.'),
              if (_error != null) _Notice(text: _error!, isError: true),
              if (_message != null) _Notice(text: _message!),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'No folders yet. Create Atlas and Harbor to begin the card tests.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._folders.map((folder) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.folder_outlined)),
                        title: Text(folder.name),
                        subtitle: Text('ID: ${folder.id} · ${folder.cardCount} card(s)'),
                        onTap: _busy ? null : () => _openFolder(folder),
                        trailing: IconButton(
                          tooltip: 'Delete ${folder.name}',
                          onPressed: _busy ? null : () => _deleteFolder(folder),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
}

class FolderDetailScreen extends StatefulWidget {
  final LocalRepository repository;
  final Folder folder;
  const FolderDetailScreen({
    super.key,
    required this.repository,
    required this.folder,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<CardRecord> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await widget.repository.getCards(widget.folder.id);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not load cards: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load cards. Please refresh.';
      });
    }
  }

  Future<void> _addOrEditCard({CardRecord? existing}) async {
    final values = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => CardFormDialog(existing: existing),
    );
    if (values == null) {
      if (mounted) setState(() => _message = 'Card edit cancelled. No changes saved.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    final card = CardRecord(
      id: existing?.id,
      title: values['title']!.trim(),
      suit: values['suit']!,
      notes: (values['notes'] ?? '').trim(),
      imageRef: (values['image_ref'] ?? '').trim().isEmpty
          ? null
          : values['image_ref']!.trim(),
      folderId: widget.folder.id,
    );
    try {
      if (existing == null) {
        final id = await widget.repository.insertCard(card);
        if (mounted) setState(() => _message = 'Card saved with ID $id.');
      } else {
        final affected = await widget.repository.updateCard(card);
        if (mounted) setState(() => _message = affected == 1
            ? 'Card ID ${existing.id} updated.'
            : 'Card ID ${existing.id} was not found.');
      }
      if (mounted) await _loadCards();
    } catch (error, stackTrace) {
      debugPrint('Could not save card: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not save the card.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCard(CardRecord card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete "${card.title}" (ID ${card.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      if (mounted) setState(() => _message = 'Card deletion cancelled.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final affected = await widget.repository.deleteCard(card.id!);
      if (!mounted) return;
      setState(() => _message = affected == 1
          ? 'Card ID ${card.id} deleted.'
          : 'Card ID ${card.id} was not found.');
      await _loadCards();
    } catch (error, stackTrace) {
      debugPrint('Could not delete card: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not delete the card.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.folder.name),
          actions: [
            IconButton(
              tooltip: 'Refresh cards',
              onPressed: _busy ? null : _loadCards,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _addOrEditCard(),
          icon: const Icon(Icons.add),
          label: const Text('Add Card'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadCards,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Text('Folder ID: ${widget.folder.id}', style: Theme.of(context).textTheme.titleMedium),
              Text('${_cards.length} card(s)'),
              if (_error != null) _Notice(text: _error!, isError: true),
              if (_message != null) _Notice(text: _message!),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('This folder is empty. Add a card to get started.', textAlign: TextAlign.center),
                )
              else
                ..._cards.map((card) => Card(
                      child: ListTile(
                        leading: CardArtwork(card: card),
                        title: Text(card.title),
                        subtitle: Text(
                          'ID: ${card.id} · ${card.suit}' +
                              (card.notes.isEmpty ? '' : '\n${card.notes}'),
                        ),
                        isThreeLine: card.notes.isNotEmpty,
                        trailing: PopupMenuButton<String>(
                          enabled: !_busy,
                          onSelected: (action) {
                            if (action == 'edit') _addOrEditCard(existing: card);
                            if (action == 'delete') _deleteCard(card);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
}

class CardFormDialog extends StatefulWidget {
  final CardRecord? existing;
  const CardFormDialog({super.key, this.existing});

  @override
  State<CardFormDialog> createState() => _CardFormDialogState();
}

class _CardFormDialogState extends State<CardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;
  late String _suit;

  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
    _imageController = TextEditingController(text: widget.existing?.imageRef ?? '');
    _suit = widget.existing?.suit ?? suits.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Add card' : 'Edit card ID ${widget.existing!.id}'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Card title'),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Card title cannot be blank.',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _suit,
                  decoration: const InputDecoration(labelText: 'Suit'),
                  items: suits.map((suit) => DropdownMenuItem(value: suit, child: Text(suit))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _suit = value);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    hintText: 'Leave blank for suit-symbol fallback',
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, <String, String?>{
                'title': _titleController.text.trim(),
                'suit': _suit,
                'notes': _notesController.text.trim(),
                'image_ref': _imageController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class CardArtwork extends StatelessWidget {
  final CardRecord card;
  const CardArtwork({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final image = card.imageRef?.trim() ?? '';
    if (image.startsWith('https://') || image.startsWith('http://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          image,
          width: 52,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SuitFallback(suit: card.suit),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: 52,
                  height: 64,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }
    return SuitFallback(suit: card.suit);
  }
}

class SuitFallback extends StatelessWidget {
  final String suit;
  const SuitFallback({super.key, required this.suit});

  @override
  Widget build(BuildContext context) {
    final symbol = switch (suit) {
      'Hearts' => '♥',
      'Diamonds' => '♦',
      'Clubs' => '♣',
      'Spades' => '♠',
      _ => '🂠',
    };
    final color = (suit == 'Hearts' || suit == 'Diamonds') ? Colors.red : Colors.black87;
    return Container(
      width: 52,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(symbol, style: TextStyle(fontSize: 30, color: color)),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final bool isError;
  const _Notice({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text),
      );
}