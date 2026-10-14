import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not open local storage. Check the logs.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Storage Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: HomeScreen(helper: helper),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final DatabaseHelper helper;

  const HomeScreen({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local Storage Lab'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Guests', icon: Icon(Icons.people)),
              Tab(text: 'Folders', icon: Icon(Icons.folder)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GuestScreen(helper: helper),
            FolderScreen(helper: helper),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// GUESTS: Part I functionality
// ------------------------------------------------------------

class GuestScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const GuestScreen({super.key, required this.helper});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _guests = [];
  int _count = 0;
  int? _editingId;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final guests = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _guests = guests;
        _count = count;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not load guests: $error');
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a guest name.';
    }
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null || age < 0 || age > 130) {
      return 'Enter a whole-number age from 0 to 130.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());

      if (_editingId == null) {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        if (mounted) setState(() => _message = 'Guest saved. ID: $id');
      } else {
        final id = _editingId!;
        final changed = await widget.helper.update({
          DatabaseHelper.columnId: id,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        if (mounted) {
          setState(() {
            _message = changed == 1
                ? 'Guest $id updated.'
                : 'Guest $id was not found.';
          });
        }
      }

      _editingId = null;
      _nameController.clear();
      _ageController.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Save failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGuest(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete guest $id — $name?'),
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

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await widget.helper.delete(id);
      await _load();
      if (mounted) {
        setState(() {
          _message = deleted == 1
              ? 'Guest $id deleted.'
              : 'Guest $id was not found.';
          if (_editingId == id) _cancelEdit();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Delete failed: $error');
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _ageController.clear();
      _message = 'Edit cancelled. No changes saved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_busy,
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
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                validator: _validateAge,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _editingId == null ? 'Add Guest' : 'Save Changes',
                  ),
                ),
              ),
              if (_editingId != null)
                TextButton(
                  onPressed: _busy ? null : _cancelEdit,
                  child: const Text('Cancel Edit'),
                ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, textAlign: TextAlign.center),
        ],
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Festival Guests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Count: $_count'),
          ],
        ),
        const SizedBox(height: 8),
        if (_guests.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No festival guests yet.'),
          ),
        ..._guests.map((guest) {
          final id = guest[DatabaseHelper.columnId] as int;
          final name = guest[DatabaseHelper.columnName] as String;
          final age = guest[DatabaseHelper.columnAge] as int;

          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: Text('ID: $id · Age: $age'),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') {
                    setState(() {
                      _editingId = id;
                      _nameController.text = name;
                      _ageController.text = age.toString();
                      _message = 'Editing guest $id.';
                    });
                  } else if (action == 'delete') {
                    _deleteGuest(id, name);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Guests'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// FOLDERS
// ------------------------------------------------------------

class FolderScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const FolderScreen({super.key, required this.helper});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await widget.helper.queryFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load folders: $error';
      });
    }
  }

  Future<void> _addFolder() async {
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const FolderNameScreen()),
    );

    if (name == null || !mounted) return;

    try {
      final id = await widget.helper.insertFolder(name);
      await _loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder saved with ID $id.')),
        );
      }
    } on DatabaseException catch (error) {
      if (!mounted) return;
      final message = error.isUniqueConstraintError()
          ? 'A folder with that exact name already exists.'
          : 'Could not save folder: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save folder: $error')),
      );
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final id = folder['id'] as int;
    final name = folder['name'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "$name" and all cards inside it?\n'
          'This cannot be undone.',
        ),
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

    if (confirmed != true || !mounted) return;

    try {
      await widget.helper.deleteFolder(id);
      await _loadFolders();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete folder: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFolder,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('Add Folder'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _folders.isEmpty
                  ? const Center(
                      child: Text('No folders yet. Tap Add Folder to begin.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFolders,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 8,
                          bottom: 90,
                        ),
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          final id = folder['id'] as int;
                          final name = folder['name'] as String;
                          final count = folder['card_count'] as int;

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(name),
                              subtitle: Text(
                                'Folder ID: $id · Cards: $count',
                              ),
                              onTap: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FolderDetailScreen(
                                      helper: widget.helper,
                                      folderId: id,
                                      folderName: name,
                                    ),
                                  ),
                                );
                                if (mounted) await _loadFolders();
                              },
                              trailing: IconButton(
                                tooltip: 'Delete folder',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteFolder(folder),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// A separate route for folder creation avoids putting the form
// inside a dialog.

class FolderNameScreen extends StatefulWidget {
  const FolderNameScreen({super.key});

  @override
  State<FolderNameScreen> createState() => _FolderNameScreenState();
}

class _FolderNameScreenState extends State<FolderNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Folder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Folder name cannot be blank.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(context, _controller.text.trim());
                  },
                  child: const Text('Save Folder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CARDS INSIDE A FOLDER
// ------------------------------------------------------------

class FolderDetailScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final int folderId;
  final String folderName;

  const FolderDetailScreen({
    super.key,
    required this.helper,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await widget.helper.queryCards(widget.folderId);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load cards: $error';
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? card]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardEditorScreen(
          helper: widget.helper,
          folderId: widget.folderId,
          existingCard: card,
        ),
      ),
    );

    if (saved == true && mounted) await _loadCards();
  }

  Future<void> _deleteCard(Map<String, dynamic> card) async {
    final id = card['id'] as int;
    final title = card['title'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete "$title" (ID $id)?'),
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

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await widget.helper.deleteCard(id);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $deleted card(s).')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete card: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _cards.isEmpty
                  ? const Center(
                      child: Text('This folder is empty. Add a card to begin.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCards,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 8,
                          bottom: 90,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final imageRef = card['image_ref'] as String?;
                          final suit = card['suit'] as String;
                          final id = card['id'] as int;

                          return Card(
                            child: ListTile(
                              leading: imageRef != null &&
                                      imageRef.trim().isNotEmpty
                                  ? Image.network(
                                      imageRef,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _SuitFallback(suit: suit),
                                    )
                                  : _SuitFallback(suit: suit),
                              title: Text(card['title'] as String),
                              subtitle: Text(
                                'ID: $id · $suit'
                                '${(card['notes'] as String).isNotEmpty ? '\n${card['notes']}' : ''}',
                              ),
                              isThreeLine:
                                  (card['notes'] as String).isNotEmpty,
                              onTap: () => _openEditor(card),
                              trailing: IconButton(
                                tooltip: 'Delete card',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteCard(card),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _SuitFallback extends StatelessWidget {
  final String suit;

  const _SuitFallback({required this.suit});

  @override
  Widget build(BuildContext context) {
    const symbols = {
      'Hearts': '♥',
      'Diamonds': '♦',
      'Clubs': '♣',
      'Spades': '♠',
    };

    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          symbols[suit] ?? '🃏',
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CARD EDITOR
// ------------------------------------------------------------

class CardEditorScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final int folderId;
  final Map<String, dynamic>? existingCard;

  const CardEditorScreen({
    super.key,
    required this.helper,
    required this.folderId,
    this.existingCard,
  });

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;

  static const _suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  String _suit = 'Hearts';
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existingCard != null;

  @override
  void initState() {
    super.initState();
    final card = widget.existingCard;

    _titleController = TextEditingController(
      text: card?['title'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: card?['notes'] as String? ?? '',
    );
    _imageController = TextEditingController(
      text: card?['image_ref'] as String? ?? '',
    );

    if (card != null && _suits.contains(card['suit'])) {
      _suit = card['suit'] as String;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final imageText = _imageController.text.trim();
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'suit': _suit,
        'notes': _notesController.text.trim(),
        'image_ref': imageText.isEmpty ? null : imageText,
        'folder_id': widget.folderId,
      };

      if (_editing) {
        await widget.helper.updateCard(
          widget.existingCard!['id'] as int,
          data,
        );
      } else {
        await widget.helper.insertCard(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save card: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Card' : 'Add Card'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Card title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Card title cannot be blank.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _suit,
                  decoration: const InputDecoration(
                    labelText: 'Suit',
                    border: OutlineInputBorder(),
                  ),
                  items: _suits
                      .map(
                        (suit) => DropdownMenuItem(
                          value: suit,
                          child: Text(suit),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _suit = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    hintText: 'Leave blank to use the suit symbol',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save Card'),
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}