import 'package:flutter/material.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint(
      'Database initialization failed: $error\n$stackTrace',
    );

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not open local storage. '
                'Restart the app and check the logs.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    return;
  }

  runApp(
    DirectoryApp(helper: helper),
  );
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({
    super.key,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fall Festival Roster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        useMaterial3: true,
      ),
      home: RosterScreen(helper: helper),
    );
  }
}

class RosterScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const RosterScreen({
    super.key,
    required this.helper,
  });

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _ageController =
      TextEditingController();

  List<Map<String, dynamic>> _rows = [];

  int _count = 0;

  bool _loading = true;
  bool _busy = false;

  int? _selectedId;

  String? _errorMessage;
  String? _feedbackMessage;

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

  // ------------------------------------------------------------
  // LOAD DATA
  // ------------------------------------------------------------

  Future<void> _loadGuests() async {
    if (_busy) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _rows = rows;
        _count = count;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load guests: $error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'Could not load guests. Please try again.';
      });
    }
  }

  // ------------------------------------------------------------
  // VALIDATION
  // ------------------------------------------------------------

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Please enter a guest name.';
    }

    return null;
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Please enter an age.';
    }

    final age = int.tryParse(text);

    if (age == null) {
      return 'Age must be a whole number.';
    }

    if (age < 0 || age > 130) {
      return 'Age must be between 0 and 130.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // ADD / EDIT
  // ------------------------------------------------------------

  Future<void> _saveGuest() async {
    if (_busy) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());

    setState(() {
      _busy = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    try {
      if (_selectedId == null) {
        // ADD
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) {
          return;
        }

        setState(() {
          _nameController.clear();
          _ageController.clear();
          _feedbackMessage = 'Guest saved with ID $id.';
        });
      } else {
        // EDIT
        final selectedId = _selectedId!;

        final updated = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) {
          return;
        }

        if (updated == 1) {
          setState(() {
            _selectedId = null;
            _nameController.clear();
            _ageController.clear();
            _feedbackMessage =
                'Guest ID $selectedId updated successfully.';
          });
        } else {
          setState(() {
            _feedbackMessage =
                'Guest ID $selectedId was not found.';
          });
        }
      }

      // Refresh the visible list after a successful write.
      try {
        final rows = await widget.helper.queryAllRows();
        final count = await widget.helper.queryRowCount();

        if (!mounted) {
          return;
        }

        setState(() {
          _rows = rows;
          _count = count;
        });
      } catch (error, stackTrace) {
        debugPrint(
          'Save succeeded, but refresh failed: '
          '$error\n$stackTrace',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = 'Saved, but refresh failed. '
              'Please press Refresh.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Could not save guest: $error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Could not save the guest. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // EDIT
  // ------------------------------------------------------------

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) {
      return;
    }

    final int id = row[DatabaseHelper.columnId] as int;
    final String name = row[DatabaseHelper.columnName] as String;
    final int age = row[DatabaseHelper.columnAge] as int;

    setState(() {
      _selectedId = id;
      _nameController.text = name;
      _ageController.text = age.toString();
      _feedbackMessage = 'Editing guest ID $id.';
      _errorMessage = null;
    });
  }

  // ------------------------------------------------------------
  // CANCEL EDIT
  // ------------------------------------------------------------

  void _cancelEdit() {
    if (_busy) {
      return;
    }

    setState(() {
      _selectedId = null;
      _nameController.clear();
      _ageController.clear();
      _feedbackMessage = 'Edit cancelled. No changes were saved.';
      _errorMessage = null;
    });

    _formKey.currentState?.reset();
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    if (_busy) {
      return;
    }

    final int id = row[DatabaseHelper.columnId] as int;
    final String name = row[DatabaseHelper.columnName] as String;
    final int age = row[DatabaseHelper.columnAge] as int;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text(
            'ID $id — $name, age $age\n\n'
            'Are you sure you want to delete this guest?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      if (mounted) {
        setState(() {
          _feedbackMessage =
              'Deletion cancelled. No changes were made.';
        });
      }

      return;
    }

    await _deleteGuest(id);
  }

  Future<void> _deleteGuest(int id) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    try {
      final deleted = await widget.helper.delete(id);

      if (!mounted) {
        return;
      }

      if (deleted == 1) {
        if (_selectedId == id) {
          _selectedId = null;
          _nameController.clear();
          _ageController.clear();
        }

        setState(() {
          _feedbackMessage =
              'Guest ID $id deleted successfully.';
        });
      } else {
        setState(() {
          _feedbackMessage =
              'Guest ID $id no longer exists.';
        });
      }

      // Refresh after deletion.
      try {
        final rows = await widget.helper.queryAllRows();
        final count = await widget.helper.queryRowCount();

        if (!mounted) {
          return;
        }

        setState(() {
          _rows = rows;
          _count = count;
        });
      } catch (error, stackTrace) {
        debugPrint(
          'Delete succeeded, but refresh failed: '
          '$error\n$stackTrace',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage =
              'Delete succeeded, but refresh failed. '
              'Please press Refresh.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Could not delete guest: $error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Could not delete the guest. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // BUILD UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    _buildForm(),
                    const SizedBox(height: 16),
                    _buildControls(),
                    const SizedBox(height: 16),
                    _buildStatus(),
                    const SizedBox(height: 16),
                    _buildRosterHeader(),
                    const SizedBox(height: 8),
                    _buildGuestList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FORM
  // ------------------------------------------------------------

  Widget _buildForm() {
    final editing = _selectedId != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Guest name',
              hintText: 'Enter a name',
              border: OutlineInputBorder(),
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ageController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Age',
              hintText: 'Enter an age from 0 to 130',
              border: OutlineInputBorder(),
            ),
            validator: _validateAge,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _saveGuest,
            child: Text(
              editing ? 'Save Changes' : 'Add Guest',
            ),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _cancelEdit,
              child: const Text('Cancel Edit'),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // REFRESH
  // ------------------------------------------------------------

  Widget _buildControls() {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _loadGuests,
      icon: const Icon(Icons.refresh),
      label: const Text('Refresh'),
    );
  }

  // ------------------------------------------------------------
  // STATUS
  // ------------------------------------------------------------

  Widget _buildStatus() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_feedbackMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Text(
          _feedbackMessage!,
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ------------------------------------------------------------
  // ROSTER HEADER
  // ------------------------------------------------------------

  Widget _buildRosterHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Festival Guests',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Count: $_count',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // GUEST LIST
  // ------------------------------------------------------------

  Widget _buildGuestList() {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No festival guests yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sortedRows = List<Map<String, dynamic>>.from(_rows);

    sortedRows.sort(
      (a, b) {
        final int idA =
            a[DatabaseHelper.columnId] as int;
        final int idB =
            b[DatabaseHelper.columnId] as int;

        return idA.compareTo(idB);
      },
    );

    return Column(
      children: sortedRows.map((row) {
        final int id =
            row[DatabaseHelper.columnId] as int;
        final String name =
            row[DatabaseHelper.columnName] as String;
        final int age =
            row[DatabaseHelper.columnAge] as int;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: $id',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Name: $name'),
                Text('Age: $age'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _startEdit(row),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _confirmDelete(row),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}