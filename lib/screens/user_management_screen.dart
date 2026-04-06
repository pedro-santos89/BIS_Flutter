import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';

/// Admin-only screen for managing application users.
///
/// Provides a list of all [AppUser]s with actions to create new users,
/// change passwords, toggle admin/normal roles, and delete users.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

/// State for [UserManagementScreen].
///
/// Loads all users on init and refreshes after every mutation
/// (create, password change, role toggle, delete).
class _UserManagementScreenState extends State<UserManagementScreen> {
  /// Cached list of all app users, refreshed by [_loadUsers].
  List<AppUser> _users = [];

  /// Whether the user list is currently being fetched from the database.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// Fetches all users from the database and updates the UI.
  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await DatabaseHelper.instance.getUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  /// Opens the create-user dialog and reloads the list on success.
  Future<void> _createUser() async {
    final result = await _showUserDialog(null);
    if (result == true) _loadUsers();
  }

  /// Shows a dialog to set a new password for [user].
  Future<void> _changePassword(AppUser user) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl.trArgs('changePasswordTitle', {'username': user.username})),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: dl.tr('newPassword'),
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? dl.tr('required') : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(dl.tr('changePasswordButton')),
            ),
          ],
        );
      },
    );

    if (confirmed == true && user.id != null) {
      await DatabaseHelper.instance
          .updateUserPassword(user.id!, controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.trArgs('passwordChanged', {'username': user.username}))),
      );
    }
    controller.dispose();
  }

  /// Toggles [user] between admin and normal role after confirmation.
  Future<void> _toggleRole(AppUser user) async {
    if (user.id == null) return;
    final newIsAdmin = !user.isAdmin;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl.tr('changeRole')),
          content: Text(
            dl.trArgs('changeRoleConfirm', {'username': user.username, 'role': newIsAdmin ? dl.tr('admin') : dl.tr('normalUser')}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl.tr('save')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.updateUserRole(user.id!, newIsAdmin);
      _loadUsers();
    }
  }

  /// Deletes [user] from the database after confirmation and reloads the list.
  Future<void> _deleteUser(AppUser user) async {
    if (user.id == null) return;
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl.tr('deleteUserTitle')),
          content: Text(dl.trArgs('deleteUserConfirm', {'username': user.username})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(dl.tr('delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteUser(user.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('deletedUser', {'username': user.username}))),
      );
      _loadUsers();
    }
  }

  /// Shows a dialog for creating a new user or editing an existing one.
  ///
  /// Returns `true` if the user was successfully created/updated.
  Future<bool?> _showUserDialog(AppUser? existing) async {
    final usernameController =
        TextEditingController(text: existing?.username ?? '');
    final passwordController = TextEditingController();
    bool isAdmin = existing?.isAdmin ?? false;
    final formKey = GlobalKey<FormState>();
    final isNew = existing == null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dl = AppLocalizations.of(ctx);
          return AlertDialog(
          title: Text(isNew ? dl.tr('createUser') : dl.tr('editUser')),
          content: SizedBox(
            width: 350,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: dl.tr('username'),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: isNew,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? dl.tr('required') : null,
                  ),
                  const SizedBox(height: 12),
                  if (isNew) ...[
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: dl.tr('password'),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? dl.tr('required') : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    title: Text(dl.tr('adminSwitch')),
                    subtitle: Text(isAdmin
                        ? dl.tr('adminSwitchSubtitleOn')
                        : dl.tr('adminSwitchSubtitleOff')),
                    value: isAdmin,
                    onChanged: (v) =>
                        setDialogState(() => isAdmin = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl.tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isNew) {
                    await DatabaseHelper.instance.createUser(
                      usernameController.text.trim(),
                      passwordController.text,
                      isAdmin,
                    );
                  } else {
                    await DatabaseHelper.instance
                        .updateUserRole(existing.id!, isAdmin);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(dl.trArgs('errorPrefix', {'error': e.toString()}))),
                    );
                  }
                }
              },
              child: Text(isNew ? dl.tr('create') : dl.tr('save')),
            ),
          ],
        );
        },
      ),
    );

    usernameController.dispose();
    passwordController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = AppTheme.hoverColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('userManagement')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createUser,
        tooltip: l.tr('createUser'),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Text(l.tr('noUsersFound')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _UserTile(
                      user: user,
                      hoverColor: hoverColor,
                      onChangePassword: () => _changePassword(user),
                      onToggleRole: () => _toggleRole(user),
                      onDelete: () => _deleteUser(user),
                    );
                  },
                ),
    );
  }
}

/// A single row in the user list showing name, role badge, and action icons.
///
/// Tracks mouse hover state to highlight the tile on desktop.
class _UserTile extends StatefulWidget {
  final AppUser user;
  final Color hoverColor;
  final VoidCallback onChangePassword;
  final VoidCallback onToggleRole;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.hoverColor,
    required this.onChangePassword,
    required this.onToggleRole,
    required this.onDelete,
  });

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovering
              ? primary.withValues(alpha: 0.1)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                widget.user.isAdmin
                    ? Icons.admin_panel_settings
                    : Icons.person,
                size: 32,
                color: _hovering ? widget.hoverColor : primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: TextStyle(
                        color: _hovering ? widget.hoverColor : primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.isAdmin ? l.tr('administrator') : l.tr('normalUser'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: widget.user.isAdmin
                    ? l.tr('demoteToNormal')
                    : l.tr('promoteToAdmin'),
                child: GestureDetector(
                  onTap: widget.onToggleRole,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      widget.user.isAdmin
                          ? Icons.person_outline
                          : Icons.admin_panel_settings,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: l.tr('changePassword'),
                child: GestureDetector(
                  onTap: widget.onChangePassword,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.lock_reset, size: 20),
                  ),
                ),
              ),
              Tooltip(
                message: l.tr('deleteUser'),
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete, size: 20, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
