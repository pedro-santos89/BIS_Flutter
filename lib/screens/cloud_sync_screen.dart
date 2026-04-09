import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../cloud/cloud_storage_provider.dart';
import '../cloud/google_drive_provider.dart';
import '../cloud/dropbox_provider.dart';
import '../cloud/onedrive_provider.dart';
import '../cloud/supabase_provider.dart';
import '../cloud/sync_engine.dart';
import '../l10n.dart';
import 'cloud_file_browser_dialog.dart';
import 'export_data_dialog.dart';

/// Cloud sync & backup management screen.
/// Allows configuring cloud providers, backing up/restoring the database,
/// syncing with conflict-aware merge, and managing files on cloud storage.
class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final Map<CloudProviderType, CloudStorageProvider> _providers = {};
  CloudProviderType? _activeProvider;
  bool _loading = false;
  String? _statusMessage;
  List<CloudFileInfo> _cloudFiles = [];

  @override
  void initState() {
    super.initState();
    _providers[CloudProviderType.googleDrive] = GoogleDriveProvider();
    _providers[CloudProviderType.dropbox] = DropboxProvider();
    _providers[CloudProviderType.oneDrive] = OneDriveProvider();
    _providers[CloudProviderType.supabase] = SupabaseProvider();
  }

  CloudStorageProvider? get _currentProvider =>
      _activeProvider != null ? _providers[_activeProvider!] : null;

  SyncEngine? get _syncEngine =>
      _currentProvider != null ? SyncEngine(_currentProvider!) : null;

  void _setStatus(String message) {
    setState(() => _statusMessage = message);
  }

  Future<void> _runWithLoading(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // Provider configuration dialogs removed. All credentials are now embedded in code.

  // ─── Authentication ───

  Future<void> _connect(CloudProviderType type) async {
    await _runWithLoading(() async {
      final provider = _providers[type]!;
      final success = await provider.authenticate();
      if (success) {
        setState(() => _activeProvider = type);
        _setStatus('Connected to ${provider.displayName}');
        await _refreshFileList();
      } else {
        _setStatus('Failed to connect to ${provider.displayName}. Check credentials.');
      }
    });
  }

  Future<void> _disconnect() async {
    if (_currentProvider == null) return;
    await _runWithLoading(() async {
      await _currentProvider!.signOut();
      _setStatus('Disconnected from ${_currentProvider!.displayName}');
      setState(() {
        _activeProvider = null;
        _cloudFiles = [];
      });
    });
  }

  // ─── Sync Operations ───

  Future<void> _backupToCloud() async {
    if (_syncEngine == null) return;
    await _runWithLoading(() async {
      await _syncEngine!.backupToCloud();
      _setStatus('Backup uploaded successfully');
      await _refreshFileList();
    });
  }

  Future<void> _restoreFromCloud() async {
    if (_syncEngine == null) return;
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('restoreFromCloud')),
        content: Text(l.tr('restoreFromCloudConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _runWithLoading(() async {
      final result = await _syncEngine!.syncFromCloud();
      _setStatus(result.summary);
    });
  }

  Future<void> _fullSync() async {
    if (_syncEngine == null) return;
    await _runWithLoading(() async {
      final result = await _syncEngine!.fullSync();
      _setStatus(result.summary);
      await _refreshFileList();
    });
  }

  // ─── File Management ───

  Future<void> _refreshFileList() async {
    if (_currentProvider == null) return;
    try {
      final files = await _currentProvider!.listFiles();
      setState(() => _cloudFiles = files);
    } catch (e) {
      setState(() => _cloudFiles = []);
    }
  }

  /// Allows user to upload one or more files from local computer to cloud storage.
  /// First shows a folder picker dialog to select the destination cloud folder,
  /// then shows a file picker to select local files (supports multiple selection),
  /// and finally uploads all selected files to the chosen cloud folder.
  Future<void> _uploadFiles() async {
    if (_currentProvider == null) return;

    // First, let the user pick a destination folder via the cloud browser
    final selectedFolder = await CloudFileBrowserDialog.showFolderPicker(context, _currentProvider!);
    if (selectedFolder == null) return;  // User cancelled
    // selectedFolder is '' for root, or a folder ID string

    // Then pick local files (multiple selection enabled)
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;

    await _runWithLoading(() async {
      for (final file in result.files) {
        if (file.path == null) continue;
        final bytes = await File(file.path!).readAsBytes();
        await _currentProvider!.uploadFileToFolder(
          file.name, bytes, selectedFolder == '' ? null : selectedFolder,
        );
      }
      final count = result.files.length;
      _setStatus('Uploaded $count file${count > 1 ? 's' : ''} to selected folder');
    });
  }

  Future<void> _downloadFile(CloudFileInfo file) async {
    if (_currentProvider == null) return;

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save file',
      fileName: file.name,
    );
    if (outputPath == null) return;

    await _runWithLoading(() async {
      final data = await _currentProvider!.downloadFile(file.id);
      await File(outputPath).writeAsBytes(data);
      _setStatus('Downloaded ${file.name}');
    });
  }

  Future<void> _deleteCloudFile(CloudFileInfo file) async {
    if (_currentProvider == null) return;

    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteFile')),
        content: Text(l.tr('deleteFileConfirm').replaceAll('{name}', file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.tr('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _runWithLoading(() async {
      await _currentProvider!.deleteFile(file.id);
      _setStatus('Deleted ${file.name}');
      await _refreshFileList();
    });
  }

  Future<void> _importFromCloudFile(CloudFileInfo file) async {
    if (_syncEngine == null) return;

    if (!file.name.endsWith('.json')) {
      _setStatus('Only JSON backup files can be imported');
      return;
    }

    await _runWithLoading(() async {
      final result = await _syncEngine!.importFromCloudFile(file.id);
      _setStatus('Import complete. ${result.summary}');
    });
  }

  Future<void> _browseAndSelectFile() async {
    if (_currentProvider == null) return;

    final selectedFile = await CloudFileBrowserDialog.show(context, _currentProvider!);
    if (selectedFile == null || !mounted) return;

    if (!selectedFile.name.endsWith('.json')) {
      _setStatus(AppLocalizations.of(context).tr('onlyJsonFiles'));
      return;
    }

    // Confirm sync with selected file
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('importData')),
        content: Text(
          l.tr('importFileConfirm').replaceAll('{name}', selectedFile.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _runWithLoading(() async {
      final result = await _syncEngine!.importFromCloudFile(selectedFile.id);
      _setStatus('${l.tr('importComplete')} ${result.summary}');
    });
  }

  /// Shows a dialog for selecting which tables to export as CSV to cloud storage.
  /// User can select Members, Daily Members, Custom Tables, or export all at once.
  /// Each selected table is exported as a separate CSV file with timestamp in filename.
  Future<void> _exportDataToCloud() async {
    if (_syncEngine == null) return;

    // Show export selection dialog
    final selections = await ExportDataDialog.show(context);
    if (selections == null || selections.isEmpty || !mounted) return;

    await _runWithLoading(() async {
      final count = await _syncEngine!.exportSelectedTablesToCloud(selections);
      final l = AppLocalizations.of(context);
      _setStatus('${l.tr('exportComplete')}: $count ${l.tr('files')}');
      await _refreshFileList();
    });
  }

  /// Allows user to download multiple files from cloud storage to local computer.
  /// Shows cloud file browser in multi-select mode with checkboxes,
  /// then prompts for local download directory, and downloads all selected files.
  Future<void> _browseCloudStorage() async {
    if (_currentProvider == null) return;

    final selectedFiles = await CloudFileBrowserDialog.showMultiSelect(context, _currentProvider!);
    if (selectedFiles == null || selectedFiles.isEmpty || !mounted) return;

    // Let user pick a download directory
    final l = AppLocalizations.of(context);
    final outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.tr('selectDownloadFolder'),
    );
    if (outputDir == null) return;

    await _runWithLoading(() async {
      for (final file in selectedFiles) {
        final data = await _currentProvider!.downloadFile(file.id);
        final outputPath = p.join(outputDir, file.name);
        await File(outputPath).writeAsBytes(data);
      }
      final count = selectedFiles.length;
      _setStatus('Downloaded $count file${count > 1 ? 's' : ''} to $outputDir');
    });
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('cloudSync')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status bar
                if (_statusMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.onPrimaryContainer, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _statusMessage = null),
                        ),
                      ],
                    ),
                  ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),

                // ─── Provider Selection ───
                Text(l.tr('cloudProviders'),
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _buildProviderCard(
                  icon: Icons.cloud,
                  title: 'Google Drive',
                  type: CloudProviderType.googleDrive,
                ),
                _buildProviderCard(
                  icon: Icons.cloud_queue,
                  title: 'Dropbox',
                  type: CloudProviderType.dropbox,
                ),
                _buildProviderCard(
                  icon: Icons.cloud_circle,
                  title: 'OneDrive',
                  type: CloudProviderType.oneDrive,
                ),
                _buildProviderCard(
                  icon: Icons.storage,
                  title: 'Supabase',
                  type: CloudProviderType.supabase,
                ),

                // ─── Sync Actions ───
                if (_activeProvider != null) ...[
                  const SizedBox(height: 24),
                  Text(l.tr('syncActions'),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(l.tr('backupToCloud')),
                        onPressed: _loading ? null : _backupToCloud,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.cloud_download),
                        label: Text(l.tr('restoreFromCloud')),
                        onPressed: _loading ? null : _restoreFromCloud,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.sync),
                        label: Text(l.tr('fullSync')),
                        onPressed: _loading ? null : _fullSync,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: Text(l.tr('uploadFiles')),
                        onPressed: _loading ? null : _uploadFiles,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.folder_open),
                        label: Text(l.tr('browseAndImport')),
                        onPressed: _loading ? null : _browseAndSelectFile,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_circle),
                        label: Text(l.tr('browseCloudStorage')),
                        onPressed: _loading ? null : _browseCloudStorage,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(l.tr('exportDataToCloud')),
                        onPressed: _loading ? null : _exportDataToCloud,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: Text(l.tr('disconnect')),
                        onPressed: _loading ? null : _disconnect,
                      ),
                    ],
                  ),

                  // ─── Cloud Files ───
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(l.tr('cloudFiles'),
                          style: theme.textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: l.tr('refresh'),
                        onPressed: _loading ? null : _refreshFileList,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_cloudFiles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(l.tr('noCloudFiles'),
                            style: theme.textTheme.bodyMedium),
                      ),
                    )
                  else
                    ..._cloudFiles.map((file) => _buildFileCard(file)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required IconData icon,
    required String title,
    required CloudProviderType type,
  }) {
    final isActive = _activeProvider == type;
    final isConnected = _providers[type]?.isAuthenticated ?? false;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon,
            color: isActive ? theme.colorScheme.primary : null),
        title: Text(title,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? theme.colorScheme.primary : null,
            )),
        subtitle: Text(isConnected
            ? l.tr('connected')
            : l.tr('notConnected')),
        trailing: FilledButton(
          onPressed: _loading
              ? null
              : () => isConnected ? _disconnect() : _connect(type),
          child:
              Text(isConnected ? l.tr('disconnect') : l.tr('connect')),
        ),
      ),
    );
  }

  Widget _buildFileCard(CloudFileInfo file) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final isBackup = file.name.startsWith('bis_backup_') && file.name.endsWith('.json');
    final sizeStr = file.sizeBytes != null
        ? _formatFileSize(file.sizeBytes!)
        : '';
    final dateStr = file.modifiedAt != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(file.modifiedAt!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          isBackup ? Icons.backup : Icons.insert_drive_file,
          color: isBackup ? theme.colorScheme.primary : null,
        ),
        title: Text(file.name),
        subtitle: Text([sizeStr, dateStr].where((s) => s.isNotEmpty).join(' • ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBackup)
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                tooltip: l.tr('importData'),
                onPressed: _loading ? null : () => _importFromCloudFile(file),
              ),
            IconButton(
              icon: const Icon(Icons.save_alt, size: 20),
              tooltip: l.tr('downloadFile'),
              onPressed: _loading ? null : () => _downloadFile(file),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: l.tr('delete'),
              onPressed: _loading ? null : () => _deleteCloudFile(file),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
