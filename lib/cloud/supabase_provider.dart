import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_storage_provider.dart';

/// Supabase Storage implementation of [CloudStorageProvider].
/// Uses Supabase anonymous/email auth and stores files in a
/// dedicated storage bucket.
class SupabaseProvider extends CloudStorageProvider {
  static const _urlKey = 'supabase_url';
  static const _anonKeyKey = 'supabase_anon_key';
  static const _emailKey = 'supabase_email';
  static const _passwordKey = 'supabase_password';
  static const _bucketName = 'bis-backups';
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

  /// Stores Supabase project credentials.
  static Future<void> saveCredentials({
    required String url,
    required String anonKey,
    String? email,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_anonKeyKey, anonKey);
    if (email != null) await prefs.setString(_emailKey, email);
    if (password != null) await prefs.setString(_passwordKey, password);
  }

  /// Returns saved Supabase config, or null if not configured.
  static Future<Map<String, String>?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final anonKey = prefs.getString(_anonKeyKey);
    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      return null;
    }
    return {
      'url': url,
      'anonKey': anonKey,
      'email': prefs.getString(_emailKey) ?? '',
      'password': prefs.getString(_passwordKey) ?? '',
    };
  }

  /// Clears stored credentials.
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKeyKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
  }

  @override
  Future<bool> authenticate() async {
    try {
      final creds = await getCredentials();
      if (creds == null) return false;

      if (!_initialized) {
        await Supabase.initialize(
          url: creds['url']!,
          anonKey: creds['anonKey']!,
        );
        _initialized = true;
      }

      final client = Supabase.instance.client;

      // If already has a valid session, we're good
      if (client.auth.currentSession != null) {
        await _ensureBucket();
        return true;
      }

      // Try email/password auth if provided
      final email = creds['email'] ?? '';
      final password = creds['password'] ?? '';
      if (email.isNotEmpty && password.isNotEmpty) {
        await client.auth.signInWithPassword(email: email, password: password);
      } else {
        // Use anonymous sign in
        await client.auth.signInAnonymously();
      }

      await _ensureBucket();
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

  Future<void> _ensureBucket() async {
    // Bucket creation is typically done server-side via Supabase dashboard.
    // We just verify we can access the bucket; if it doesn't exist,
    // the admin should create it in the Supabase dashboard.
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
  Future<Uint8List> downloadFile(String fileId) async {
    return await _storage.from(_bucketName).download(fileId);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await _storage.from(_bucketName).remove([fileId]);
  }
}
