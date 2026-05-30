import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:br_core/br_core.dart';

class BrApiClient {
  final Uri _base;
  final http.Client _http;
  String? _jwt;
  final String _jwtCachePath;

  BrApiClient({
    required Uri baseUrl,
    http.Client? httpClient,
    String? jwtCachePath,
  })  : _base = baseUrl,
        _http = httpClient ?? http.Client(),
        _jwtCachePath = jwtCachePath ??
            '${Platform.environment['HOME'] ?? '.'}/.broccers/cli-jwt' {
    final f = File(_jwtCachePath);
    if (f.existsSync()) _jwt = f.readAsStringSync().trim();
  }

  Uri get baseUrl => _base;
  String? get jwt => _jwt;
  bool get isAuthenticated => _jwt != null && _jwt!.isNotEmpty;

  Future<Result<String, SgFailure>> authenticate(String pin) async {
    try {
      final resp = await _http.post(
        _base.resolve('/api/auth/pin'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      );
      if (resp.statusCode != 200) {
        return Failure(SgBrocAuthFailure('HTTP ${resp.statusCode}: ${resp.body}'));
      }
      final token = (jsonDecode(resp.body) as Map<String, dynamic>)['token'] as String;
      _jwt = token;
      final f = File(_jwtCachePath);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(token);
      return Success(token);
    } catch (e) {
      return Failure(SgNetworkFailure('auth failed', cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, SgFailure>> command(String cmd) async {
    try {
      final resp = await _http.post(
        _base.resolve('/api/command'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'cmd': cmd}),
      );
      return Success(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (e) {
      return Failure(SgNetworkFailure('command failed', cause: e));
    }
  }

  Future<Result<Uint8List, SgFailure>> downloadPdf(String cardId) async {
    if (!isAuthenticated) {
      return const Failure(SgBrocAuthFailure('not authenticated'));
    }
    try {
      final resp = await _http.get(
        _base.resolve('/api/menu/cards/$cardId/pdf'),
        headers: {'authorization': 'Bearer $_jwt'},
      );
      if (resp.statusCode != 200) {
        return Failure(SgNetworkFailure('HTTP ${resp.statusCode}: ${resp.body}'));
      }
      return Success(resp.bodyBytes);
    } catch (e) {
      return Failure(SgNetworkFailure('pdf download failed', cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, SgFailure>> health() async {
    try {
      final resp = await _http.get(_base.resolve('/api/health'));
      if (resp.statusCode != 200) {
        return Failure(SgNetworkFailure('HTTP ${resp.statusCode}'));
      }
      return Success(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (e) {
      return Failure(SgNetworkFailure('health failed', cause: e));
    }
  }
}
