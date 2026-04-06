import 'dart:typed_data';

/// Metadata about a file or folder stored in a cloud service.
class CloudFileInfo {
  final String id;
  final String name;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isFolder;

  CloudFileInfo({
    required this.id,
    required this.name,
    this.mimeType,
    this.sizeBytes,
    this.modifiedAt,
    this.isFolder = false,
  });
}

/// Result of a sync operation, with counts for each action taken.
class SyncResult {
  final int membersUploaded;
  final int membersDownloaded;
  final int dailyMembersUploaded;
  final int dailyMembersDownloaded;
  final int customTablesUploaded;
  final int customTablesDownloaded;
  final int conflicts;
  final int errors;
  final String summary;

  SyncResult({
    this.membersUploaded = 0,
    this.membersDownloaded = 0,
    this.dailyMembersUploaded = 0,
    this.dailyMembersDownloaded = 0,
    this.customTablesUploaded = 0,
    this.customTablesDownloaded = 0,
    this.conflicts = 0,
    this.errors = 0,
    this.summary = '',
  });
}

/// Supported cloud storage providers.
enum CloudProviderType { googleDrive, dropbox, oneDrive, supabase }

/// Abstract interface for cloud storage operations.
/// Each provider (Google Drive, Dropbox, OneDrive, Supabase) implements this.
abstract class CloudStorageProvider {
  /// Human-readable display name of this provider.
  String get displayName;

  /// The provider type enum value.
  CloudProviderType get providerType;

  /// Whether the user is currently authenticated with this provider.
  bool get isAuthenticated;

  /// Initiates OAuth2 / authentication flow for this provider.
  /// Returns true if authentication succeeded.
  Future<bool> authenticate();

  /// Signs out and clears stored tokens.
  Future<void> signOut();

  /// Lists files in the BIS app folder on this provider.
  Future<List<CloudFileInfo>> listFiles();

  /// Lists files and folders in the specified folder.
  /// If [folderId] is null, lists the root of the cloud drive.
  /// Returns both files and folders (with [CloudFileInfo.isFolder] = true).
  Future<List<CloudFileInfo>> listFilesInFolder(String? folderId);

  /// Uploads raw bytes as a file. Returns the cloud file ID.
  Future<String> uploadFile(String fileName, Uint8List data, {String? mimeType});

  /// Downloads a file by its cloud ID. Returns raw bytes.
  Future<Uint8List> downloadFile(String fileId);

  /// Deletes a file by its cloud ID.
  Future<void> deleteFile(String fileId);

  /// Uploads the database backup JSON to the cloud.
  Future<String> uploadDatabaseBackup(Uint8List jsonData) {
    final now = DateTime.now();
    final filename =
        'bis_backup_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.json';
    return uploadFile(filename, jsonData, mimeType: 'application/json');
  }

  /// Downloads the most recent database backup from the cloud.
  /// Returns null if no backups exist.
  Future<Uint8List?> downloadLatestBackup() async {
    final files = await listFiles();
    final backups = files
        .where((f) => f.name.startsWith('bis_backup_') && f.name.endsWith('.json'))
        .toList();
    if (backups.isEmpty) return null;
    backups.sort((a, b) => (b.modifiedAt ?? DateTime(0)).compareTo(a.modifiedAt ?? DateTime(0)));
    return downloadFile(backups.first.id);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
