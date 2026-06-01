import 'dart:convert';

import 'package:br_core/br_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BrWebApi {
  final Uri baseUrl;
  final http.Client _http;
  String? _jwt;

  BrWebApi({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<void> loadCachedJwt() async {
    final prefs = await SharedPreferences.getInstance();
    _jwt = prefs.getString('br_jwt');
  }

  bool get isAuthenticated => _jwt != null && _jwt!.isNotEmpty;
  String? get jwt => _jwt;

  Future<Result<String, SgFailure>> authenticate(String pin) async {
    try {
      final resp = await _http.post(
        baseUrl.resolve('/api/auth/pin'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      );
      if (resp.statusCode != 200) {
        return Failure(SgBrocAuthFailure('HTTP ${resp.statusCode}: ${resp.body}'));
      }
      final token = (jsonDecode(resp.body) as Map<String, dynamic>)['token'] as String;
      _jwt = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('br_jwt', token);
      return Success(token);
    } catch (e) {
      return Failure(SgNetworkFailure('auth failed', cause: e));
    }
  }

  Future<void> logout() async {
    _jwt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('br_jwt');
  }

  Future<Result<Map<String, dynamic>, SgFailure>> get(String path) =>
      _req('GET', path, null);

  Future<Result<Map<String, dynamic>, SgFailure>> post(
    String path,
    Map<String, dynamic>? body,
  ) =>
      _req('POST', path, body);

  Future<Result<Map<String, dynamic>, SgFailure>> put(
    String path,
    Map<String, dynamic>? body,
  ) =>
      _req('PUT', path, body);

  Future<Result<Map<String, dynamic>, SgFailure>> delete(String path) =>
      _req('DELETE', path, null);

  /// Exécute une commande TestControlServer (sans auth car pas requis).
  Future<Result<Map<String, dynamic>, SgFailure>> command(String cmd) async {
    try {
      final resp = await _http.post(
        baseUrl.resolve('/api/command'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'cmd': cmd}),
      );
      return Success(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (e) {
      return Failure(SgNetworkFailure('command failed', cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, SgFailure>> _req(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    if (!isAuthenticated) {
      return const Failure(SgBrocAuthFailure('not authenticated'));
    }
    final headers = {
      'authorization': 'Bearer $_jwt',
      'content-type': 'application/json',
    };
    try {
      http.Response resp;
      final uri = baseUrl.resolve(path);
      if (method == 'GET') {
        resp = await _http.get(uri, headers: headers);
      } else if (method == 'PUT') {
        resp = await _http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      } else if (method == 'DELETE') {
        resp = await _http.delete(uri, headers: headers);
      } else {
        resp = await _http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
      if (resp.statusCode == 401) {
        await logout();
        return const Failure(SgBrocAuthFailure('session expired'));
      }
      if (resp.statusCode >= 400) {
        return Failure(SgNetworkFailure('HTTP ${resp.statusCode}: ${resp.body}'));
      }
      if (resp.body.isEmpty) return const Success({});
      return Success(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (e) {
      return Failure(SgNetworkFailure('request failed', cause: e));
    }
  }
}
