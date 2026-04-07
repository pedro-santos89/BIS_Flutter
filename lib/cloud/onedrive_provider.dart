import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_storage_provider.dart';

/// OneDrive (Microsoft Graph) implementation of [CloudStorageProvider].
/// Uses OAuth2 authorization code flow for desktop.
/// Stores files in a dedicated "BIS_Backups" folder in the user's OneDrive.
class OneDriveProvider extends CloudStorageProvider {
  // EMBEDDED OAUTH CREDENTIALS (replace with your registered Azure app client ID)
  static const String _clientId = 'YOUR_ONEDRIVE_CLIENT_ID';
  static const _tokenKey = 'onedrive_access_token';
  static const _refreshTokenKey = 'onedrive_refresh_token';
  static const _folderName = 'BIS_Backups';
  static const _redirectPort = 8543;
  static const _graphBase = 'https://graph.microsoft.com/v1.0';
  static const _scopes = 'Files.ReadWrite offline_access';

  String? _accessToken;

  @override
  String get displayName => 'OneDrive';

  @override
  CloudProviderType get providerType => CloudProviderType.oneDrive;

  @override
  bool get isAuthenticated => _accessToken != null;

  @override
  Future<bool> authenticate() async {
    try {
      // Try restoring saved token
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      if (savedToken != null) {
        _accessToken = savedToken;
        try {
          await _graphGet('/me');
          return true;
        } catch (_) {
          // Token expired, try refresh
          final refreshToken = prefs.getString(_refreshTokenKey);
          if (refreshToken != null) {
            final refreshed = await _refreshTokenFlow(refreshToken);
            if (refreshed) return true;
          }
          _accessToken = null;
        }
      }

      final redirectUri = 'http://localhost:$_redirectPort/callback';

      // Start local server
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);

      final authUrl = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': _scopes,
        'response_mode': 'query',
      });

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      }

      String? authCode;
      await for (final request in server) {
        if (request.uri.path == '/callback') {
          authCode = request.uri.queryParameters['code'];
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('<html><body><h2>Authentication successful!</h2><p>You can close this window.</p></body></html>');
          await request.response.close();
          break;
        }
        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      }
      await server.close();

      if (authCode == null) return false;

      // Exchange code for token
      final tokenResponse = await http.post(
        Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': authCode,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'scope': _scopes,
        },
      );

      if (tokenResponse.statusCode != 200) return false;

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      _accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;

      await prefs.setString(_tokenKey, _accessToken!);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }

      await _ensureFolder();
      return true;
    } catch (e) {
      _accessToken = null;
      return false;
    }
  }

  Future<bool> _refreshTokenFlow(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': _scopes,
        },
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _accessToken!);
      if (newRefresh != null) {
        await prefs.setString(_refreshTokenKey, newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<http.Response> _graphGet(String path) async {
    if (_accessToken == null) throw StateError('Not authenticated');
    return http.get(
      Uri.parse('$_graphBase$path'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
  }

  Future<void> _ensureFolder() async {
    // Check if folder exists
    final checkResponse = await _graphGet('/me/drive/root:/$_folderName');
    if (checkResponse.statusCode == 200) return;

    // Create folder
    final response = await http.post(
      Uri.parse('$_graphBase/me/drive/root/children'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': _folderName,
        'folder': {},
        '@microsoft.graph.conflictBehavior': 'fail',
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 409) {
      // 409 = already exists, which is fine
      throw Exception('Failed to create folder: ${response.statusCode}');
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles() async {
    final response = await _graphGet('/me/drive/root:/$_folderName:/children');
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['value'] as List<dynamic>? ?? [];

    return items
        .where((item) => item['file'] != null) // Only files, not subfolders
        .map((item) => CloudFileInfo(
              id: item['id'] as String,
              name: item['name'] as String,
              mimeType: (item['file'] as Map?)?['mimeType'] as String?,
              sizeBytes: item['size'] as int?,
              modifiedAt: DateTime.tryParse(item['lastModifiedDateTime'] as String? ?? ''),
            ))
        .toList();
  }

  @override
  Future<List<CloudFileInfo>> listFilesInFolder(String? folderId) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    // null = root of OneDrive
    final path = folderId != null
        ? '/me/drive/items/$folderId/children'
        : '/me/drive/root/children';
    final response = await _graphGet(path);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['value'] as List<dynamic>? ?? [];

    return items.map((item) {
      final isFolder = item['folder'] != null;
      return CloudFileInfo(
        id: item['id'] as String,
        name: item['name'] as String,
        mimeType: isFolder ? null : (item['file'] as Map?)?['mimeType'] as String?,
        sizeBytes: item['size'] as int?,
        modifiedAt: DateTime.tryParse(item['lastModifiedDateTime'] as String? ?? ''),
        isFolder: isFolder,
      );
    }).toList();
  }

  @override
  Future<String> uploadFile(String fileName, Uint8List data, {String? mimeType}) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    final response = await http.put(
      Uri.parse('$_graphBase/me/drive/root:/$_folderName/$fileName:/content'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': mimeType ?? 'application/octet-stream',
      },
      body: data,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return result['id'] as String;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    final response = await http.get(
      Uri.parse('$_graphBase/me/drive/items/$fileId/content'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    // Microsoft may return a 302 redirect; http package follows redirects by default
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    await http.delete(
      Uri.parse('$_graphBase/me/drive/items/$fileId'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
  }
}
