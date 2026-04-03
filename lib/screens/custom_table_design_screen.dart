import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models.dart';

class CustomTableDesignScreen extends StatefulWidget {
  const CustomTableDesignScreen({super.key});

  @override
  State<CustomTableDesignScreen> createState() =>
      _CustomTableDesignScreenState();
}

class _CustomTableDesignScreenState extends State<CustomTableDesignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tableNameController = TextEditingController();
  final List<_ColumnEntry> _columns = [];
  bool _isSubmitting = false;
  CustomTableDef? _existing;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is CustomTableDef) {
        _existing = arg;
        _tableNameController.text = arg.tableName;
        for (final col in arg.columns) {
          _columns.add(_ColumnEntry(
            nameController: TextEditingController(text: col.columnName),
            type: col.columnType,
          ));
        }
      }
      if (_columns.isEmpty) {
        _addColumn();
      }
    }
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    for (final col in _columns) {
      col.nameController.dispose();
    }
    super.dispose();
  }

  void _addColumn() {
    setState(() {
      _columns.add(_ColumnEntry(
        nameController: TextEditingController(),
        type: 'TEXT',
      ));
    });
  }

  void _removeColumn(int index) {
    if (_columns.length <= 1) return;
    setState(() {
      _columns[index].nameController.dispose();
      _columns.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final columns = _columns
          .map((c) => CustomColumnDef(
                columnName: c.nameController.text.trim(),
                columnType: c.type,
              ))
          .toList();

      if (_existing != null) {
        await DatabaseHelper.instance.updateCustomTable(
          _existing!.id!,
          _tableNameController.text.trim(),
          columns,
        );
      } else {
        await DatabaseHelper.instance.createCustomTable(
          _tableNameController.text.trim(),
          columns,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Create Custom Table' : 'Edit Table Structure'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isNew ? 'New Custom Table' : 'Edit "${_existing!.tableName}"',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!isNew)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'Warning: Editing the table structure will delete all existing data in this table.',
                        style: TextStyle(color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _tableNameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Table Name',
                      hintText: 'e.g. Volunteers, Equipment, Events',
                      prefixIcon: Icon(Icons.table_chart),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Columns',
                          style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Column'),
                        onPressed: _addColumn,
                      ),
                    ],
                  ),
                  const Divider(),
                  ...List.generate(_columns.length, (i) {
                    final col = _columns[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}.',
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: col.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Column Name',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: col.type,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'TEXT', child: Text('Text')),
                                DropdownMenuItem(
                                    value: 'INTEGER', child: Text('Integer')),
                                DropdownMenuItem(
                                    value: 'REAL', child: Text('Decimal')),
                                DropdownMenuItem(
                                    value: 'BOOLEAN',
                                    child: Text('Yes/No')),
                              ],
                              onChanged: (v) {
                                setState(() => col.type = v ?? 'TEXT');
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            tooltip: 'Remove column',
                            onPressed: _columns.length > 1
                                ? () => _removeColumn(i)
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: Icon(isNew ? Icons.add : Icons.save),
                    label: Text(isNew ? 'Create Table' : 'Save Changes'),
                    onPressed: _isSubmitting ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnEntry {
  final TextEditingController nameController;
  String type;

  _ColumnEntry({required this.nameController, required this.type});
}
