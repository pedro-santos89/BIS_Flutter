import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_storage_provider.dart';

/// Supabase Storage implementation of [CloudStorageProvider].
/// Uses Supabase anonymous/email auth and stores files in a
/// dedicated storage bucket.
class SupabaseProvider extends CloudStorageProvider {
  // Credentials loaded from .env file
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static const _bucketName = 'bis-files';
  static const _folderPath = 'backups';

  bool _initialized = false;

  @override
  String get displayName => 'Supabase';

  @override
  CloudProviderType get providerType => CloudProviderType.supabase;

  @override
  bool get isAuthenticated {
    if (!_initialized) return false;
    return Supabase.instance.client.auth.currentSession != null;
  }

  @override
  Future<bool> authenticate() async {
    try {
      if (!_initialized) {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        _initialized = true;
      }

      final client = Supabase.instance.client;

      // If already has a valid session, we're good
      if (client.auth.currentSession != null) {
        return true;
      }

      // Use anonymous sign in
      await client.auth.signInAnonymously();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialized) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }

  SupabaseStorageClient get _storage => Supabase.instance.client.storage;

  @override
  Future<List<CloudFileInfo>> listFiles() async {
    final files = await _storage.from(_bucketName).list(path: _folderPath);

    return files
        .where((f) => f.name.isNotEmpty && f.id != null)
        .map((f) => CloudFileInfo(
              id: '$_folderPath/${f.name}',
              name: f.name,
              sizeBytes: f.metadata?['size'] as int?,
              modifiedAt: f.updatedAt != null
                  ? DateTime.tryParse(f.updatedAt!)
                  : null,
            ))
        .toList();
  }

  @override
  Future<List<CloudFileInfo>> listFilesInFolder(String? folderId) async {
    // Supabase storage is flat with path prefixes.
    // folderId is the path prefix (e.g. null for bucket root, 'backups' for the backups folder).
    final path = folderId ?? '';

    final files = await _storage.from(_bucketName).list(path: path);

    return files
        .where((f) => f.name.isNotEmpty)
        .map((f) {
          final fullPath = path.isEmpty ? f.name : '$path/${f.name}';
          // Supabase marks folders with id == null and metadata == null
          final isFolder = f.id == null;
          return CloudFileInfo(
            id: fullPath,
            name: f.name,
            sizeBytes: f.metadata?['size'] as int?,
            modifiedAt: f.updatedAt != null
                ? DateTime.tryParse(f.updatedAt!)
                : null,
            isFolder: isFolder,
          );
        })
        .toList();
  }

  @override
  Future<String> uploadFile(String fileName, Uint8List data, {String? mimeType}) async {
    final path = '$_folderPath/$fileName';
    await _storage.from(_bucketName).uploadBinary(
      path,
      data,
      fileOptions: FileOptions(
        contentType: mimeType ?? 'application/octet-stream',
        upsert: true,
      ),
    );
    return path;
  }

  @override
  Future<String> uploadFileToFolder(String fileName, Uint8List data, String? folderId, {String? mimeType}) async {
    // folderId is a path prefix (e.g. 'some/folder') or null for bucket root
    final folderPrefix = folderId ?? '';
    final path = folderPrefix.isEmpty ? fileName : '$folderPrefix/$fileName';
    await _storage.from(_bucketName).uploadBinary(
      path,
      data,
      fileOptions: FileOptions(
        contentType: mimeType ?? 'application/octet-stream',
        upsert: true,
      ),
    );
    return path;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    return await _storage.from(_bucketName).download(fileId);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await _storage.from(_bucketName).remove([fileId]);
  }
}
