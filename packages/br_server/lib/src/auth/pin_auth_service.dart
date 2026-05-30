import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:br_core/br_core.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:sqlite3/sqlite3.dart';

/// Service d'authentification PIN. Copié/adapté de nono-cook.
/// MIGRATE LATER vers `sg_pin_auth` partagé.
class PinAuthService {
  final Database _db;
  final String _pinBcryptHash;
  final String _jwtSecret;
  final int _maxAttempts;
  final Duration _cooldown;
  final Duration _jwtTtl;

  PinAuthService({
    required Database db,
    required String pinBcryptHash,
    required String jwtSecret,
    int maxAttempts = 5,
    Duration cooldown = const Duration(minutes: 15),
    Duration jwtTtl = const Duration(hours: 24),
  })  : _db = db,
        _pinBcryptHash = pinBcryptHash,
        _jwtSecret = jwtSecret,
        _maxAttempts = maxAttempts,
        _cooldown = cooldown,
        _jwtTtl = jwtTtl {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS auth_attempts (
        ip TEXT NOT NULL,
        attempted_at TEXT NOT NULL
      );
    ''');
  }

  Future<Result<String, SgFailure>> authenticate({
    required String pin,
    required String clientIp,
  }) async {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(_cooldown);
    _db.execute('DELETE FROM auth_attempts WHERE attempted_at < ?',
        [cutoff.toIso8601String()]);

    final rs = _db.select(
      'SELECT COUNT(*) AS n FROM auth_attempts WHERE ip = ?',
      [clientIp],
    );
    final attempts = rs.first['n'] as int;
    if (attempts >= _maxAttempts) {
      return Failure(SgBrocAuthFailure(
        'Too many attempts from $clientIp — try again in ${_cooldown.inMinutes} min',
      ));
    }

    if (_pinBcryptHash.isEmpty) {
      return const Failure(SgValidationFailure(
        'PIN not configured (env BR_PIN_BCRYPT_HASH missing)',
      ));
    }

    bool ok;
    try {
      ok = BCrypt.checkpw(pin, _pinBcryptHash);
    } catch (e) {
      return Failure(SgValidationFailure('Bcrypt failed', cause: e));
    }

    if (!ok) {
      _db.execute('INSERT INTO auth_attempts(ip, attempted_at) VALUES (?, ?)',
          [clientIp, now.toIso8601String()]);
      return const Failure(SgBrocAuthFailure('Invalid PIN'));
    }

    _db.execute('DELETE FROM auth_attempts WHERE ip = ?', [clientIp]);

    final jwt = JWT({
      'sub': 'broccers-user',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(_jwtTtl).millisecondsSinceEpoch ~/ 1000,
    });
    return Success(jwt.sign(SecretKey(_jwtSecret), algorithm: JWTAlgorithm.HS256));
  }

  Result<Map<String, dynamic>, SgFailure> verifyJwt(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return Success(Map<String, dynamic>.from(jwt.payload as Map));
    } on JWTExpiredException {
      return const Failure(SgBrocAuthFailure('JWT expired'));
    } on JWTException catch (e) {
      return Failure(SgBrocAuthFailure('JWT invalid: ${e.message}'));
    }
  }

  static String hashPin(String pin) =>
      BCrypt.hashpw(pin, BCrypt.gensalt(logRounds: 12));

  static String generateJwtSecret() {
    final bytes = List<int>.generate(
        64, (i) => (DateTime.now().microsecondsSinceEpoch + i * 37) % 256);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String? readHashFromFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.readAsStringSync().trim();
  }
}
