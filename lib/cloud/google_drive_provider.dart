import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_storage_provider.dart';

/// Google Drive implementation of [CloudStorageProvider].
/// Uses OAuth2 desktop flow (browser redirect → localhost callback).
/// Stores files in a dedicated "BIS_Backups" folder in the user's Drive.
class GoogleDriveProvider extends CloudStorageProvider {
  // OAuth credentials loaded from .env file
  static String get _clientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get _clientSecret => dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';
  static const _tokensKey = 'google_drive_tokens';
  static const _folderName = 'BIS_Backups';
  static const _scopes = [drive.DriveApi.driveFileScope];

  AutoRefreshingAuthClient? _authClient;
  String? _folderId;

  @override
  String get displayName => 'Google Drive';

  @override
  CloudProviderType get providerType => CloudProviderType.googleDrive;

  @override
  bool get isAuthenticated => _authClient != null;


  // All credential storage logic removed. Credentials are now embedded.

  @override
  Future<bool> authenticate() async {
    try {
      final clientId = ClientId(_clientId, _clientSecret);

      // Try restoring saved tokens first
      final prefs = await SharedPreferences.getInstance();
      final savedTokens = prefs.getString(_tokensKey);
      if (savedTokens != null) {
        try {
          final tokenMap = jsonDecode(savedTokens) as Map<String, dynamic>;
          final accessToken = AccessToken(
            tokenMap['type'] as String,
            tokenMap['data'] as String,
            DateTime.parse(tokenMap['expiry'] as String).toUtc(),
          );
          final credentials = AccessCredentials(
            accessToken,
            tokenMap['refreshToken'] as String?,
            _scopes,
          );
          _authClient = autoRefreshingClient(
            clientId,
            credentials,
            http.Client(),
          );
          await _ensureFolder();
          return true;
        } catch (_) {
          // Saved tokens invalid, proceed with fresh auth
        }
      }

      // Desktop OAuth2 flow: opens browser, listens on localhost
      _authClient = await clientViaUserConsent(
        clientId,
        _scopes,
        (url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      );

      // Save tokens for next session
      if (_authClient != null) {
        final credentials = _authClient!.credentials;
        final tokenMap = {
          'type': credentials.accessToken.type,
          'data': credentials.accessToken.data,
          'expiry': credentials.accessToken.expiry.toIso8601String(),
          'refreshToken': credentials.refreshToken,
        };
        await prefs.setString(_tokensKey, jsonEncode(tokenMap));
      }

      await _ensureFolder();
      return true;
    } catch (e) {
      _authClient = null;
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    _authClient?.close();
    _authClient = null;
    _folderId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokensKey);
  }

  /// Ensures the BIS_Backups folder exists in Drive, creating it if needed.
  Future<void> _ensureFolder() async {
    if (_authClient == null) return;
    final driveApi = drive.DriveApi(_authClient!);

    // Search for existing folder
    final query =
        "name = '$_folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final result = await driveApi.files.list(q: query, spaces: 'drive');
    if (result.files != null && result.files!.isNotEmpty) {
      _folderId = result.files!.first.id;
      return;
    }

    // Create folder
    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await driveApi.files.create(folder);
    _folderId = created.id;
  }

  @override
  Future<List<CloudFileInfo>> listFiles() async {
    if (_authClient == null) throw StateError('Not authenticated');
    final driveApi = drive.DriveApi(_authClient!);

    final query =
        "'$_folderId' in parents and trashed = false";
    final result = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id,name,size,mimeType,modifiedTime)',
    );

    return (result.files ?? []).map((f) => CloudFileInfo(
      id: f.id!,
      name: f.name ?? '',
      mimeType: f.mimeType,
      sizeBytes: int.tryParse(f.size ?? ''),
      modifiedAt: f.modifiedTime,
      isFolder: f.mimeType == 'application/vnd.google-apps.folder',
    )).toList();
  }

  @override
  Future<List<CloudFileInfo>> listFilesInFolder(String? folderId) async {
    if (_authClient == null) throw StateError('Not authenticated');
    final driveApi = drive.DriveApi(_authClient!);

    final parentId = folderId ?? 'root';
    final query = "'$parentId' in parents and trashed = false";
    final result = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'folder,name',
      $fields: 'files(id,name,size,mimeType,modifiedTime)',
    );

    return (result.files ?? []).map((f) => CloudFileInfo(
      id: f.id!,
      name: f.name ?? '',
      mimeType: f.mimeType,
      sizeBytes: int.tryParse(f.size ?? ''),
      modifiedAt: f.modifiedTime,
      isFolder: f.mimeType == 'application/vnd.google-apps.folder',
    )).toList();
  }

  @override
  Future<String> uploadFile(String fileName, Uint8List data, {String? mimeType}) async {
    if (_authClient == null) throw StateError('Not authenticated');
    final driveApi = drive.DriveApi(_authClient!);

    final file = drive.File()
      ..name = fileName
      ..parents = [_folderId ?? 'root'];

    final media = drive.Media(
      Stream.fromIterable([data]),
      data.length,
      contentType: mimeType ?? 'application/octet-stream',
    );

    final result = await driveApi.files.create(file, uploadMedia: media);
    return result.id!;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    if (_authClient == null) throw StateError('Not authenticated');
    final driveApi = drive.DriveApi(_authClient!);

    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <List<int>>[];
    await for (final chunk in media.stream) {
      chunks.add(chunk);
    }
    return Uint8List.fromList(chunks.expand((c) => c).toList());
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_authClient == null) throw StateError('Not authenticated');
    final driveApi = drive.DriveApi(_authClient!);
    await driveApi.files.delete(fileId);
  }
}
