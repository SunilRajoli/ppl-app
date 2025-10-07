// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // ensure http_parser in pubspec

import 'storage_service.dart';

class ApiService {
  final StorageService _storage = StorageService();
  final http.Client _client;
  final String baseUrl;

  ApiService({
    String? overrideBaseUrl,
    http.Client? client,
  })  : baseUrl = overrideBaseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:3000/api/v1',
            ),
        _client = client ?? http.Client();

  Uri _buildUri(String pathOrUrl, [Map<String, dynamic>? query]) {
    Uri uri;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      uri = Uri.parse(pathOrUrl);
    } else {
      final normalized = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
      uri = Uri.parse('$baseUrl$normalized');
    }
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          ...query.map((k, v) => MapEntry(k, '$v'))
        },
      );
    }
    return uri;
  }

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final token = await _storage.getToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extra,
    };
  }

  dynamic _encodeBodyIfNeeded(dynamic body, Map<String, String> headers) {
    if (body == null) return null;
    final isJson =
        (headers['Content-Type'] ?? '').toLowerCase().contains('application/json');
    if (isJson && body is! String) return jsonEncode(body);
    return body;
  }

  Future<dynamic> _request(
    String pathOrUrl, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = _buildUri(pathOrUrl, query);
    final defaultHeaders = await _authHeaders();
    final mergedHeaders = {...defaultHeaders, ...?headers};

    http.Response resp;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          resp = await _client.get(uri, headers: mergedHeaders).timeout(timeout);
          break;
        case 'POST':
          resp = await _client
              .post(uri,
                  headers: mergedHeaders,
                  body: _encodeBodyIfNeeded(body, mergedHeaders))
              .timeout(timeout);
          break;
        case 'PUT':
          resp = await _client
              .put(uri,
                  headers: mergedHeaders,
                  body: _encodeBodyIfNeeded(body, mergedHeaders))
              .timeout(timeout);
          break;
        case 'DELETE':
          resp = await _client
              .delete(uri,
                  headers: mergedHeaders,
                  body: _encodeBodyIfNeeded(body, mergedHeaders))
              .timeout(timeout);
          break;
        default:
          throw UnsupportedError('HTTP method $method is not supported');
      }
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error');
    } on FormatException {
      throw ApiException(message: 'Invalid server response');
    } catch (e) {
      throw ApiException(message: e.toString());
    }

    return _handleResponse(resp);
  }

  dynamic _handleResponse(http.Response response) {
    final text = response.body;
    dynamic data;
    try {
      data = text.isNotEmpty ? jsonDecode(text) : null;
    } catch (_) {
      data = text;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data ?? <String, dynamic>{};
    }

    String message = 'Request failed with status ${response.statusCode}';
    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? data['errors'] ?? message)
          .toString();
      if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
        final first = (data['errors'] as List).first;
        if (first is Map && first['message'] != null) {
          message = first['message'].toString();
        } else {
          message = first.toString();
        }
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    throw ApiException(message: message, statusCode: response.statusCode, data: data);
  }

  MediaType? _guessMediaType(String? filename) {
    final ext = (filename ?? '').split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mpeg':
      case 'mpg':
        return MediaType('video', 'mpeg');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'webm':
        return MediaType('video', 'webm');
      case 'zip':
        return MediaType('application', 'zip');
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'txt':
        return MediaType('text', 'plain');
      default:
        return null;
    }
  }

  Future<dynamic> _multipart(
    String path, {
    Map<String, String>? fields,
    Map<String, File>? files,
    Map<String, List<File>>? fileLists,
    Map<String, String>? headers,
    String method = 'POST',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = _buildUri(path);
    final token = await _storage.getToken();

    final req = http.MultipartRequest(method, uri);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    if (headers != null) req.headers.addAll(headers);
    if (fields != null) req.fields.addAll(fields);

    if (files != null) {
      for (final entry in files.entries) {
        final file = entry.value;
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final filename = file.path.split('/').last;
        req.files.add(http.MultipartFile(
          entry.key,
          stream,
          length,
          filename: filename,
          contentType: _guessMediaType(filename), // set correct MIME
        ));
      }
    }

    if (fileLists != null) {
      for (final entry in fileLists.entries) {
        for (final file in entry.value) {
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          final filename = file.path.split('/').last;
          req.files.add(http.MultipartFile(
            entry.key,
            stream,
            length,
            filename: filename,
            contentType: _guessMediaType(filename), // set correct MIME
          ));
        }
      }
    }

    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(timeout);
    } on TimeoutException {
      throw ApiException(message: 'Upload timed out');
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } catch (e) {
      throw ApiException(message: e.toString());
    }

    final resp = await http.Response.fromStream(streamed);
    return _handleResponse(resp);
  }

  Future<dynamic> _multipartBytes(
    String path, {
    Map<String, String>? fields,
    Map<String, _BytesPayload>? bytesSingles,
    Map<String, List<_BytesPayload>>? bytesLists,
    Map<String, String>? headers,
    String method = 'POST',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = _buildUri(path);
    final token = await _storage.getToken();

    final req = http.MultipartRequest(method, uri);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    if (headers != null) req.headers.addAll(headers);
    if (fields != null) req.fields.addAll(fields);

    if (bytesSingles != null) {
      for (final entry in bytesSingles.entries) {
        final bp = entry.value;
        req.files.add(http.MultipartFile.fromBytes(
          entry.key,
          bp.bytes,
          filename: bp.filename ?? 'file',
          contentType: _guessMediaType(bp.filename), // set correct MIME
        ));
      }
    }

    if (bytesLists != null) {
      for (final entry in bytesLists.entries) {
        for (final bp in entry.value) {
          req.files.add(http.MultipartFile.fromBytes(
            entry.key,
            bp.bytes,
            filename: bp.filename ?? 'file',
            contentType: _guessMediaType(bp.filename), // set correct MIME
          ));
        }
      }
    }

    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(timeout);
    } on TimeoutException {
      throw ApiException(message: 'Upload timed out');
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } catch (e) {
      throw ApiException(message: e.toString());
    }

    final resp = await http.Response.fromStream(streamed);
    return _handleResponse(resp);
  }

  // ---------------------------
  // AUTH
  // ---------------------------

  Future<dynamic> register(Map<String, dynamic> userData) async {
    return _request('/auth/register', method: 'POST', body: userData);
  }

  Future<dynamic> login({
    required String email,
    required String password,
    String? role,
  }) async {
    final body = {'email': email, 'password': password, if (role != null) 'role': role};
    return _request('/auth/login', method: 'POST', body: body);
  }

  Future<dynamic> logout() async {
    return _request('/auth/logout', method: 'POST');
  }

  Future<dynamic> getProfile() async {
    return _request('/auth/profile', method: 'GET');
  }

  Future<dynamic> updateProfile(Map<String, dynamic> payload) async {
    return _request('/auth/profile', method: 'PUT', body: payload);
  }

  Future<dynamic> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final body = {
      'newPassword': newPassword,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'currentPassword': currentPassword,
    };
    return _request('/auth/change-password', method: 'POST', body: body);
  }

  Future<dynamic> forgotPassword(String email) async {
    return _request('/auth/forgot-password',
        method: 'POST', body: {'email': email});
  }

  Future<dynamic> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return _request('/auth/reset-password',
        method: 'POST', body: {'token': token, 'newPassword': newPassword});
  }

  /// Returns: { "data": { "authUrl": "<full url>" } }
  Future<Map<String, dynamic>> getGoogleAuthUrl({
    String? redirectUri,
    String? state,
  }) async {
    final params = <String, dynamic>{
      if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
      if (state != null && state.isNotEmpty) 'state': state,
    };
    final uri = _buildUri('/auth/google', params);
    return {'data': {'authUrl': uri.toString()}};
  }

  /// Returns: { "data": { "authUrl": "<full url>" } }
  Future<Map<String, dynamic>> getGitHubAuthUrl({
    String? redirectUri,
    String? state,
  }) async {
    final params = <String, dynamic>{
      if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
      if (state != null && state.isNotEmpty) 'state': state,
    };
    final uri = _buildUri('/auth/github', params);
    return {'data': {'authUrl': uri.toString()}};
  }

  /// Exchange provider code for a JWT/session (backend should return token + user)
  Future<dynamic> exchangeOAuthCode({
    required String code,
    required String provider, // "google" | "github"
    String? redirectUri,
  }) async {
    final body = {
      'code': code,
      'provider': provider,
      if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
    };
    return _request('/auth/oauth/exchange', method: 'POST', body: body);
  }

  // ---------------------------
  // COMPETITIONS
  // ---------------------------

  Future<dynamic> listCompetitions() async {
    return _request('/competitions', method: 'GET');
  }

  Future<dynamic> getCompetition(String id) async {
    return _request('/competitions/$id', method: 'GET');
  }

  Future<dynamic> createCompetition(Map<String, dynamic> payload) async {
    return _request('/competitions', method: 'POST', body: payload);
  }

  Future<dynamic> updateCompetition(String id, Map<String, dynamic> payload) async {
    return _request('/competitions/$id', method: 'PUT', body: payload);
  }

  Future<dynamic> deleteCompetition(String id) async {
    return _request('/competitions/$id', method: 'DELETE');
  }

  Future<dynamic> registerForCompetition(String id, Map<String, dynamic> payload) async {
    return _request('/competitions/$id/register', method: 'POST', body: payload);
  }

  // ✅ ADDED: matches GET /competitions/:id/registrations (hiring/investor/admin)
  Future<dynamic> getCompetitionRegistrations(String competitionId) async {
    return _request('/competitions/$competitionId/registrations', method: 'GET');
  }

  // DEPRECATED: old wrong endpoint
  @Deprecated('Use createSubmission instead.')
  Future<dynamic> submitCompetitionEntry(String id, Map<String, dynamic> payload) async {
    // Intentionally call the correct endpoint to avoid 404s if used anywhere
    return _request('/submissions/$id', method: 'POST', body: payload);
  }

  /// Preferred helper for creating a submission
  Future<dynamic> createCompetitionSubmission(String competitionId, Map<String, dynamic> payload) async {
    // Route to the correct backend endpoint
    return createSubmission(competitionId, payload);
  }

  Future<dynamic> getCompetitionLeaderboard(String id) async {
    return _request('/competitions/$id/leaderboard', method: 'GET');
  }

  Future<dynamic> getCompetitionRegistrationStats(String id) async {
    return _request('/competitions/$id/registration-stats', method: 'GET');
  }

  // ---------------------------
  // VIDEOS
  // ---------------------------

  Future<dynamic> getFeed({
    int page = 1,
    int limit = 12,
    String? search,
    String? tags,
    String? uploader,
  }) async {
    final query = <String, dynamic>{
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      if (uploader != null && uploader.isNotEmpty) 'uploader': uploader,
    };
    return _request('/videos/feed', method: 'GET', query: query);
  }

  Future<dynamic> getVideoById(String id) async {
    return _request('/videos/$id', method: 'GET');
  }

  Future<dynamic> toggleVideoLike(String id, {bool? liked}) async {
    final body = <String, dynamic>{if (liked != null) 'liked': liked};
    return _request('/videos/$id/like', method: 'POST', body: body);
  }

  Future<dynamic> uploadVideo({
    required File videoFile,
    required String title,
    String? summary,
    String? repoUrl,
    String? driveUrl,
    String? competitionId,
    File? zip,
    List<File>? attachments,
  }) async {
    final fields = <String, String>{
      'title': title,
      if (summary != null) 'summary': summary,
      if (repoUrl != null) 'repo_url': repoUrl,
      if (driveUrl != null) 'drive_url': driveUrl,
      if (competitionId != null) 'competition_id': competitionId,
    };

    final singles = <String, File>{
      'video': videoFile,
      if (zip != null) 'zip': zip,
    };

    final lists = <String, List<File>>{
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
    };

    return _multipart(
      '/videos',
      fields: fields,
      files: singles,
      fileLists: lists,
    );
  }

  Future<dynamic> uploadVideoFromBytes({
    required Uint8List videoBytes,
    required String videoFilename,
    required String title,
    String? summary,
    String? repoUrl,
    String? driveUrl,
    String? competitionId,
    Uint8List? zipBytes,
    String? zipFilename,
    List<Uint8List>? attachmentsBytes,
    List<String>? attachmentsFilenames,
  }) async {
    final fields = <String, String>{
      'title': title,
      if (summary != null && summary.isNotEmpty) 'summary': summary,
      if (repoUrl != null && repoUrl.isNotEmpty) 'repo_url': repoUrl,
      if (driveUrl != null && driveUrl.isNotEmpty) 'drive_url': driveUrl,
      if (competitionId != null && competitionId.isNotEmpty) 'competition_id': competitionId,
    };

    final singles = <String, _BytesPayload>{
      'video': _BytesPayload(bytes: videoBytes, filename: videoFilename),
      if (zipBytes != null && (zipFilename ?? '').isNotEmpty)
        'zip': _BytesPayload(bytes: zipBytes, filename: zipFilename!),
    };

    final lists = <String, List<_BytesPayload>>{};
    if (attachmentsBytes != null && attachmentsBytes.isNotEmpty) {
      final names = attachmentsFilenames ??
          List<String>.filled(attachmentsBytes.length, 'file');
      final payloads = <_BytesPayload>[];
      for (var i = 0; i < attachmentsBytes.length; i++) {
        payloads.add(_BytesPayload(bytes: attachmentsBytes[i], filename: names[i]));
      }
      lists['attachments'] = payloads;
    }

    return _multipartBytes(
      '/videos',
      fields: fields,
      bytesSingles: singles,
      bytesLists: lists,
    );
  }

  // ---------------------------
  // PERKS
  // ---------------------------

  Future<dynamic> getPerks({int page = 1, int limit = 50, String? search}) async {
    final query = <String, dynamic>{
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    return _request('/perks', method: 'GET', query: query);
  }

  Future<dynamic> redeemPerk(String perkId) async {
    return _request('/perks/$perkId/redeem', method: 'POST');
  }

  // ---------------------------
  // USERS by ROLE
  // ---------------------------

  Future<dynamic> getUsersByRole(String role) async {
    return _request('/users', method: 'GET', query: {'role': role});
  }

  // ---------------------------
  // SUBMISSIONS
  // ---------------------------

  Future<dynamic> createSubmission(String competitionId, Map<String, dynamic> payload) async {
    return _request('/submissions/$competitionId', method: 'POST', body: payload);
  }

  Future<dynamic> listMySubmissions() async {
    return _request('/submissions/my', method: 'GET');
  }

  Future<dynamic> listSubmissionsByCompetition(String competitionId) async {
    return _request('/submissions/competition/$competitionId', method: 'GET');
  }

  Future<dynamic> updateSubmission(String submissionId, Map<String, dynamic> payload) async {
    return _request('/submissions/$submissionId', method: 'PUT', body: payload);
  }

  /// ✅ ADDED: matches POST /submissions/competition/:competitionId/publish
  Future<dynamic> publishCompetitionResults(String competitionId) async {
    return _request('/submissions/competition/$competitionId/publish', method: 'POST');
  }

  // ---------------------------
  // ADMIN
  // ---------------------------

  Future<dynamic> inviteAdmin({required String name, required String email}) async {
    return _request('/admin/invite', method: 'POST', body: {'name': name, 'email': email});
  }

  Future<dynamic> getAdminList() async {
    return _request('/admin/list', method: 'GET');
  }

  Future<dynamic> deactivateAdmin(String adminId) async {
    return _request('/admin/$adminId/deactivate', method: 'DELETE');
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class _BytesPayload {
  final Uint8List bytes;
  final String? filename;
  _BytesPayload({required this.bytes, this.filename});
}
