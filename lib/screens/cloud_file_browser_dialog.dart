import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../cloud/cloud_storage_provider.dart';
import '../l10n.dart';

/// A dialog that lets the user browse cloud storage folders and select a file.
/// Returns the selected [CloudFileInfo] or null if cancelled.
class CloudFileBrowserDialog extends StatefulWidget {
  final CloudStorageProvider provider;
  final bool folderPickerMode;
  final bool multiSelectMode;

  const CloudFileBrowserDialog({
    super.key,
    required this.provider,
    this.folderPickerMode = false,
    this.multiSelectMode = false,
  });

  /// Shows the dialog and returns the selected file, or null.
  static Future<CloudFileInfo?> show(
    BuildContext context,
    CloudStorageProvider provider,
  ) {
    return showDialog<CloudFileInfo>(
      context: context,
      builder: (_) => CloudFileBrowserDialog(provider: provider),
    );
  }

  /// Shows the dialog in multi-select mode and returns the selected files.
  static Future<List<CloudFileInfo>?> showMultiSelect(
    BuildContext context,
    CloudStorageProvider provider,
  ) {
    return showDialog<List<CloudFileInfo>>(
      context: context,
      builder: (_) => CloudFileBrowserDialog(provider: provider, multiSelectMode: true),
    );
  }

  /// Shows the dialog in folder-picker mode and returns the selected folder ID.
  /// Returns '' for root, the folder ID string for a selected folder, or null if cancelled.
  static Future<String?> showFolderPicker(
    BuildContext context,
    CloudStorageProvider provider,
  ) {
    return showDialog<String>(
      context: context,
      builder: (_) => CloudFileBrowserDialog(provider: provider, folderPickerMode: true),
    );
  }

  @override
  State<CloudFileBrowserDialog> createState() => _CloudFileBrowserDialogState();
}

class _CloudFileBrowserDialogState extends State<CloudFileBrowserDialog> {
  List<CloudFileInfo> _items = []; // Files and folders in current directory
  bool _loading = true; // Loading state while fetching cloud files
  String? _error; // Error message if file listing fails
  final Set<String> _selectedFileIds = {}; // Track selected file IDs in multi-select mode

  // Navigation stack: each entry is (folderId, folderName).
  // The first entry represents the root.
  final List<_BreadcrumbEntry> _pathStack = [
    _BreadcrumbEntry(id: null, name: 'Root'),
  ];

  String? get _currentFolderId => _pathStack.last.id;

  @override
  void initState() {
    super.initState();
    _loadFolder(null);
  }

  Future<void> _loadFolder(String? folderId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.provider.listFilesInFolder(folderId);
      // Sort: folders first, then files, alphabetically within each group
      items.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _navigateInto(CloudFileInfo folder) {
    _pathStack.add(_BreadcrumbEntry(id: folder.id, name: folder.name));
    _loadFolder(folder.id);
  }

  void _navigateToIndex(int index) {
    if (index >= _pathStack.length - 1) return; // Already there
    // Remove everything after the target index
    _pathStack.removeRange(index + 1, _pathStack.length);
    _loadFolder(_currentFolderId);
  }

  void _navigateUp() {
    if (_pathStack.length <= 1) return;
    _pathStack.removeLast();
    _loadFolder(_currentFolderId);
  }

  /// Handles file selection. In multi-select mode, toggles file in selection set.
  /// In single-select mode, immediately returns the selected file and closes dialog.
  void _selectFile(CloudFileInfo file) {
    if (widget.multiSelectMode) {
      setState(() {
        if (_selectedFileIds.contains(file.id)) {
          _selectedFileIds.remove(file.id);
        } else {
          _selectedFileIds.add(file.id);
        }
      });
    } else {
      Navigator.of(context).pop(file);
    }
  }

  /// Confirms multi-selection and returns the list of selected files to caller.
  void _confirmMultiSelection() {
    final selectedFiles = _items.where((f) => _selectedFileIds.contains(f.id)).toList();
    Navigator.of(context).pop(selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 550,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Title bar ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.cloud, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${l.tr('browseCloudStorage')} — ${widget.provider.displayName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onPrimaryContainer),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l.tr('cancel'),
                  ),
                ],
              ),
            ),

            // ─── Breadcrumb navigation ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: _pathStack.length > 1 ? _navigateUp : null,
                    tooltip: l.tr('goBack'),
                    visualDensity: VisualDensity.compact,
                  ),
                  // Refresh
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loading ? null : () => _loadFolder(_currentFolderId),
                    tooltip: l.tr('refresh'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  // Breadcrumb trail
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildBreadcrumbs(theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Content ───
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48, color: theme.colorScheme.error),
                                const SizedBox(height: 12),
                                Text(_error!,
                                    style: TextStyle(color: theme.colorScheme.error)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l.tr('refresh')),
                                  onPressed: () => _loadFolder(_currentFolderId),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                l.tr('emptyFolder'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _buildItemTile(item, theme, l);
                              },
                            ),
            ),

            // ─── Bottom bar ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.multiSelectMode && _selectedFileIds.isNotEmpty
                        ? '${_selectedFileIds.length} ${l.tr('filesSelected')}'
                        : '${_items.where((i) => i.isFolder).length} ${l.tr('folders')}, '
                          '${_items.where((i) => !i.isFolder).length} ${l.tr('files')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.folderPickerMode)
                        FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: Text(l.tr('selectThisFolder')),
                          onPressed: () {
                            Navigator.of(context).pop(_currentFolderId ?? '');
                          },
                        ),
                      if (widget.multiSelectMode)
                        FilledButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text(l.tr('downloadSelected')),
                          onPressed: _selectedFileIds.isEmpty ? null : _confirmMultiSelection,
                        ),
                      if (widget.folderPickerMode || widget.multiSelectMode) const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.tr('cancel')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs(ThemeData theme) {
    final widgets = <Widget>[];
    for (var i = 0; i < _pathStack.length; i++) {
      if (i > 0) {
        widgets.add(Icon(Icons.chevron_right,
            size: 18, color: theme.colorScheme.onSurfaceVariant));
      }
      final isLast = i == _pathStack.length - 1;
      widgets.add(
        InkWell(
          onTap: isLast ? null : () => _navigateToIndex(i),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              _pathStack[i].name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                color: isLast
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildItemTile(CloudFileInfo item, ThemeData theme, AppLocalizations l) {
    final dateStr = item.modifiedAt != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(item.modifiedAt!)
        : '';
    final sizeStr =
        (!item.isFolder && item.sizeBytes != null) ? _formatSize(item.sizeBytes!) : '';
    final subtitle = [sizeStr, dateStr].where((s) => s.isNotEmpty).join(' • ');

    final isSelected = widget.multiSelectMode && _selectedFileIds.contains(item.id);

    return ListTile(
      leading: widget.multiSelectMode && !item.isFolder
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _selectFile(item),
            )
          : Icon(
              item.isFolder ? Icons.folder : _fileIcon(item.name),
              color: item.isFolder
                  ? Colors.amber.shade700
                  : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: item.isFolder
          ? const Icon(Icons.chevron_right)
          : widget.folderPickerMode
              ? null  // Don't show select button for files in folder picker mode
              : widget.multiSelectMode
                  ? null  // No trailing button in multi-select, use checkbox instead
                  : FilledButton.tonal(
                      onPressed: () => _selectFile(item),
                      child: Text(l.tr('select')),
                    ),
      onTap: item.isFolder
          ? () => _navigateInto(item)
          : widget.folderPickerMode
              ? null
              : () => _selectFile(item),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.json')) return Icons.data_object;
    if (lower.endsWith('.csv')) return Icons.table_chart;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return Icons.table_chart;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) return Icons.image;
    if (lower.endsWith('.txt')) return Icons.description;
    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _BreadcrumbEntry {
  final String? id;
  final String name;

  _BreadcrumbEntry({required this.id, required this.name});
}
