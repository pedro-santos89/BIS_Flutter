import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers.dart';
import '../theme.dart';
import '../export_helper.dart';
import '../database_helper.dart';
import '../models.dart';
import '../l10n.dart';

/// Admin dashboard screen — the central hub for authenticated users.
///
/// Displays navigation tiles for managing members, daily members,
/// reports, custom tables, user management (admin only), and
/// quick-action / database import-export buttons.
/// Redirects to the login page if the user is not authenticated.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

/// State for [AdminScreen]. Loads custom table definitions on init
/// and after returning from the custom-tables management screen.
class _AdminScreenState extends State<AdminScreen> {
  /// Cached list of user-defined custom tables shown as navigation tiles.
  List<CustomTableDef> _customTables = [];

  @override
  void initState() {
    super.initState();
    _loadCustomTables();
  }

  /// Fetches all custom table definitions from the local database.
  Future<void> _loadCustomTables() async {
    final tables = await DatabaseHelper.instance.getCustomTables();
    if (mounted) setState(() => _customTables = tables);
  }

  /// Exports the entire SQLite database to a JSON file and shows a snackbar
  /// with the output path.
  Future<void> _exportDatabase(BuildContext context) async {
    final path = await ExportHelper.exportWholeDatabase();
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trArgs('databaseExported', {'path': path}))),
      );
    }
  }

  /// Shows a confirmation dialog, then imports a JSON database file.
  /// Displays a result snackbar with member/daily-member/error counts.
  Future<void> _importDatabase(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('importDatabase')),
        content: Text(l.tr('importDatabaseMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.tr('import')),
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
            AppLocalizations.of(context).trArgs('importedResult', {
              'members': '${result['members']}',
              'dailyMembers': '${result['daily_members']}',
              'errors': '${result['errors']}',
            }),
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
        title: Text(AppLocalizations.of(context).tr('bisAdministration'),
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
          _TextSizeMenuButton(primary: theme.colorScheme.primary),
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          Builder(builder: (context) {
            final tp = context.watch<ThemeProvider>();
            return IconButton(
              icon: Text(
                tp.locale.languageCode.toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              tooltip: tp.locale.languageCode == 'pt' ? 'English' : 'Português',
              onPressed: () => tp.toggleLocale(),
            );
          }),
          TextButton.icon(
            icon: Icon(Icons.logout, color: theme.colorScheme.primary),
            label: Text(
              '${AppLocalizations.of(context).tr('logout')} (${auth.username})',
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
              AppLocalizations.of(context).tr('siteAdministration'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).trArgs('welcomeUser', {'username': auth.username ?? ''}),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context).tr('sectionRegistry'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Divider(),
            _AdminTile(
              icon: Icons.people,
              title: AppLocalizations.of(context).tr('members'),
              subtitle: AppLocalizations.of(context).tr('membersSubtitle'),
              onTap: () => Navigator.pushNamed(context, '/admin/members'),
            ),
            _AdminTile(
              icon: Icons.person_outline,
              title: AppLocalizations.of(context).tr('dailyMembers'),
              subtitle: AppLocalizations.of(context).tr('dailyMembersSubtitle'),
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/daily-members'),
            ),
            _AdminTile(
              icon: Icons.assessment,
              title: AppLocalizations.of(context).tr('registrationsReport'),
              subtitle: AppLocalizations.of(context).tr('reportSubtitle'),
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/report'),
            ),
            const Divider(height: 32),
            Text(
              AppLocalizations.of(context).tr('sectionCustomTables'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Divider(),
            _AdminTile(
              icon: Icons.table_chart,
              title: AppLocalizations.of(context).tr('manageCustomTables'),
              subtitle: AppLocalizations.of(context).tr('customTablesSubtitle'),
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
                AppLocalizations.of(context).tr('sectionUserManagement'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Divider(),
              _AdminTile(
                icon: Icons.manage_accounts,
                title: AppLocalizations.of(context).tr('users'),
                subtitle: AppLocalizations.of(context).tr('usersSubtitle'),
                onTap: () =>
                    Navigator.pushNamed(context, '/admin/users'),
              ),
            ],
            const Divider(height: 32),
            Text(
              AppLocalizations.of(context).tr('sectionQuickActions'),
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
                  label: Text(AppLocalizations.of(context).tr('addMember')),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/admin/members/add'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(AppLocalizations.of(context).tr('addDailyMember')),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/admin/daily-members/add',
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              AppLocalizations.of(context).tr('sectionDatabase'),
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
                  label: Text(AppLocalizations.of(context).tr('exportDatabase')),
                  onPressed: () => _exportDatabase(context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: Text(AppLocalizations.of(context).tr('importDatabase')),
                  onPressed: () => _importDatabase(context),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              AppLocalizations.of(context).tr('sectionCloudSync'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Divider(),
            _AdminTile(
              icon: Icons.cloud_sync,
              title: AppLocalizations.of(context).tr('cloudSync'),
              subtitle: AppLocalizations.of(context).tr('cloudSyncSubtitle'),
              onTap: () => Navigator.pushNamed(context, '/admin/cloud-sync'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hover-aware navigation tile used on the admin dashboard.
///
/// Shows an [icon], [title], and [subtitle] with a chevron. On hover
/// the icon and title color transition to [AppTheme.hoverColor] and
/// the background gets a subtle primary tint.
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
  /// Tracks mouse hover to drive color and background transitions.
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

/// Text-size dropdown button using MenuAnchor – stays open after each tap.
class _TextSizeMenuButton extends StatefulWidget {
  final Color primary;
  const _TextSizeMenuButton({required this.primary});

  @override
  State<_TextSizeMenuButton> createState() => _TextSizeMenuButtonState();
}

class _TextSizeMenuButtonState extends State<_TextSizeMenuButton> {
  /// Controller that keeps the dropdown open after each tap via
  /// [addPostFrameCallback] re-open trick.
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final scale = tp.textScale;
    final primary = widget.primary;

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        MenuItemButton(
          onPressed: scale < 2.0
              ? () {
                  tp.increaseTextScale();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _menuController.open();
                  });
                }
              : null,
          leadingIcon: const Icon(Icons.text_increase, size: 20),
          child: Text(AppLocalizations.of(context).tr('textSizeIncrease')),
        ),
        MenuItemButton(
          onPressed: () {
            tp.resetTextScale();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _menuController.open();
            });
          },
          leadingIcon: const Icon(Icons.refresh, size: 20),
          child: Text(AppLocalizations.of(context).trArgs('textSizeReset', {'percent': '${tp.textScalePercent}'})),
        ),
        MenuItemButton(
          onPressed: scale > 1.0
              ? () {
                  tp.decreaseTextScale();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _menuController.open();
                  });
                }
              : null,
          leadingIcon: const Icon(Icons.text_decrease, size: 20),
          child: Text(AppLocalizations.of(context).tr('textSizeDecrease')),
        ),
      ],
      child: InkWell(
        onTap: () {
          if (_menuController.isOpen) {
            _menuController.close();
          } else {
            _menuController.open();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('a', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
              Text('A', style: TextStyle(fontSize: 18, color: primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
