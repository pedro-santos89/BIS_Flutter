import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'cloud_storage_provider.dart';

/// Dropbox implementation of [CloudStorageProvider].
/// Uses OAuth2 PKCE flow for desktop (browser → localhost redirect).
/// Stores files in /Apps/BIS_Backups/ in the user's Dropbox.
class DropboxProvider extends CloudStorageProvider {
  // OAuth credentials loaded from .env file
  static String get _appKey => dotenv.env['DROPBOX_APP_KEY'] ?? '';
  static const _tokenKey = 'dropbox_access_token';
  static const _refreshTokenKey = 'dropbox_refresh_token';
  static const _folderPath = '/BIS_Backups';
  static const _redirectPort = 8542;

  String? _accessToken;

  @override
  String get displayName => 'Dropbox';

  @override
  CloudProviderType get providerType => CloudProviderType.dropbox;

  @override
  bool get isAuthenticated => _accessToken != null;

  @override
  Future<bool> authenticate() async {
    try {
      // Try restoring saved token first
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      if (savedToken != null) {
        _accessToken = savedToken;
        // Verify token is still valid
        try {
          await _apiCall('POST', 'https://api.dropboxapi.com/2/users/get_current_account');
          return true;
        } catch (_) {
          // Token expired, try refresh
          final refreshToken = prefs.getString(_refreshTokenKey);
          if (refreshToken != null) {
            final refreshed = await _refreshToken(refreshToken);
            if (refreshed) return true;
          }
          _accessToken = null;
        }
      }

      // Start local server to capture OAuth callback
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);
      final redirectUri = 'http://localhost:$_redirectPort/callback';

      final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
        'client_id': _appKey,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'token_access_type': 'offline',
      });

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      }

      // Wait for the callback
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
        Uri.parse('https://api.dropboxapi.com/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': authCode,
          'grant_type': 'authorization_code',
          'client_id': _appKey,
          'redirect_uri': redirectUri,
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

      // Ensure backup folder exists
      await _ensureFolder();
      return true;
    } catch (e) {
      _accessToken = null;
      return false;
    }
  }

  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _appKey,
        },
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _accessToken!);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    if (_accessToken != null) {
      try {
        await _apiCall('POST', 'https://api.dropboxapi.com/2/auth/token/revoke');
      } catch (_) {}
    }
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<void> _ensureFolder() async {
    try {
      await _apiCall(
        'POST',
        'https://api.dropboxapi.com/2/files/create_folder_v2',
        body: {'path': _folderPath, 'autorename': false},
      );
    } catch (_) {
      // Folder may already exist, that's fine
    }
  }

  Future<http.Response> _apiCall(String method, String url, {Map<String, dynamic>? body, Map<String, String>? extraHeaders}) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    final headers = {
      'Authorization': 'Bearer $_accessToken',
      ...?extraHeaders,
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final uri = Uri.parse(url);
    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        : await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      throw StateError('Authentication expired');
    }
    return response;
  }

  @override
  Future<List<CloudFileInfo>> listFiles() async {
    final response = await _apiCall(
      'POST',
      'https://api.dropboxapi.com/2/files/list_folder',
      body: {'path': _folderPath, 'recursive': false},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>? ?? [];

    return entries
        .where((e) => e['.tag'] == 'file')
        .map((e) => CloudFileInfo(
              id: e['id'] as String,
              name: e['name'] as String,
              sizeBytes: e['size'] as int?,
              modifiedAt: DateTime.tryParse(e['server_modified'] as String? ?? ''),
            ))
        .toList();
  }

  @override
  Future<List<CloudFileInfo>> listFilesInFolder(String? folderId) async {
    // Dropbox uses paths, not IDs for folder browsing.
    // folderId here is the path (e.g. '' for root, '/Documents', etc.)
    final path = folderId ?? '';

    final response = await _apiCall(
      'POST',
      'https://api.dropboxapi.com/2/files/list_folder',
      body: {'path': path, 'recursive': false},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>? ?? [];

    return entries.map((e) {
      final tag = e['.tag'] as String;
      return CloudFileInfo(
        id: e['path_lower'] as String? ?? e['id'] as String,
        name: e['name'] as String,
        sizeBytes: tag == 'file' ? (e['size'] as int?) : null,
        modifiedAt: tag == 'file'
            ? DateTime.tryParse(e['server_modified'] as String? ?? '')
            : null,
        isFolder: tag == 'folder',
      );
    }).toList();
  }

  @override
  Future<String> uploadFile(String fileName, Uint8List data, {String? mimeType}) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    final response = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': '$_folderPath/$fileName',
          'mode': 'add',
          'autorename': true,
          'mute': false,
        }),
      },
      body: data,
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return result['id'] as String;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    if (_accessToken == null) throw StateError('Not authenticated');

    // Dropbox download needs the path, but we have the ID.
    // We need to get metadata first to get the path.
    final metaResponse = await _apiCall(
      'POST',
      'https://api.dropboxapi.com/2/files/get_metadata',
      body: {'path': fileId},
    );

    String path = fileId;
    if (metaResponse.statusCode == 200) {
      final meta = jsonDecode(metaResponse.body) as Map<String, dynamic>;
      path = meta['path_lower'] as String? ?? fileId;
    }

    final response = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Dropbox-API-Arg': jsonEncode({'path': path}),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await _apiCall(
      'POST',
      'https://api.dropboxapi.com/2/files/delete_v2',
      body: {'path': fileId},
    );
  }
}
