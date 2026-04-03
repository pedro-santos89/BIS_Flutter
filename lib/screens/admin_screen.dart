import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers.dart';
import '../theme.dart';
import '../export_helper.dart';
import '../database_helper.dart';
import '../models.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<CustomTableDef> _customTables = [];

  @override
  void initState() {
    super.initState();
    _loadCustomTables();
  }

  Future<void> _loadCustomTables() async {
    final tables = await DatabaseHelper.instance.getCustomTables();
    if (mounted) setState(() => _customTables = tables);
  }

  Future<void> _exportDatabase(BuildContext context) async {
    final path = await ExportHelper.exportWholeDatabase();
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database exported to $path')),
      );
    }
  }

  Future<void> _importDatabase(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Database'),
        content: const Text(
          'This will add records from the backup file to the database. '
          'Existing records will not be deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ExportHelper.importWholeDatabase();
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result['members']} members, '
            '${result['daily_members']} daily members '
            '(${result['errors']} errors)',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('BIS Administration',
            style: TextStyle(fontFamily: AppTheme.headlineFont, fontWeight: FontWeight.normal)),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          TextButton.icon(
            icon: Icon(Icons.logout, color: theme.colorScheme.primary),
            label: Text(
              'Logout (${auth.username})',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AppTheme.hoverColor(
                      theme.brightness == Brightness.dark);
                }
                return theme.colorScheme.primary;
              }),
              overlayColor: WidgetStateProperty.all(
                AppTheme.hoverColor(theme.brightness == Brightness.dark)
                    .withValues(alpha: 0.1),
              ),
            ),
            onPressed: () {
              auth.logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site administration',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome, ${auth.username}.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            Text(
              'REGISTRY',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Divider(),
            _AdminTile(
              icon: Icons.people,
              title: 'Members',
              subtitle: 'View, add, edit and export members',
              onTap: () => Navigator.pushNamed(context, '/admin/members'),
            ),
            _AdminTile(
              icon: Icons.person_outline,
              title: 'Daily Members',
              subtitle: 'View, add, edit and export daily members',
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/daily-members'),
            ),
            _AdminTile(
              icon: Icons.assessment,
              title: 'Registrations Report',
              subtitle: 'View new registrations by date range',
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/report'),
            ),
            const Divider(height: 32),
            Text(
              'CUSTOM TABLES',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Divider(),
            _AdminTile(
              icon: Icons.table_chart,
              title: 'Manage Custom Tables',
              subtitle: 'Create, edit and delete custom tables',
              onTap: () async {
                await Navigator.pushNamed(context, '/admin/custom-tables');
                _loadCustomTables();
              },
            ),
            ..._customTables.map((table) => _AdminTile(
              icon: Icons.grid_on,
              title: table.tableName,
              subtitle: '${table.columns.length} column${table.columns.length != 1 ? 's' : ''}',
              onTap: () => Navigator.pushNamed(
                context,
                '/admin/custom-tables/data',
                arguments: table,
              ),
            )),
            if (auth.isAdmin) ...[
              const Divider(height: 32),
              Text(
                'USER MANAGEMENT',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Divider(),
              _AdminTile(
                icon: Icons.manage_accounts,
                title: 'Users',
                subtitle: 'Create, edit and manage user accounts',
                onTap: () =>
                    Navigator.pushNamed(context, '/admin/users'),
              ),
            ],
            const Divider(height: 32),
            Text(
              'QUICK ACTIONS',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Member'),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/admin/members/add'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add Daily Member'),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/admin/daily-members/add',
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'DATABASE',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export Database'),
                  onPressed: () => _exportDatabase(context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('Import Database'),
                  onPressed: () => _importDatabase(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_AdminTile> createState() => _AdminTileState();
}

class _AdminTileState extends State<_AdminTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = AppTheme.hoverColor(isDark);
    final primary = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hovering
                ? primary.withValues(alpha: 0.1)
                : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 32,
                    color: _hovering ? hoverColor : primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: _hovering ? hoverColor : primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _hovering ? hoverColor : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
