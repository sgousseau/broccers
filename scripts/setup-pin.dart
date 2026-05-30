// Setup helper : génère le hash bcrypt d'un PIN + un secret JWT pour br_server.
//
// Usage :
//   dart run scripts/setup-pin.dart <pin>

import 'dart:io';

import 'package:bcrypt/bcrypt.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run scripts/setup-pin.dart <pin>');
    exit(64);
  }
  final pin = args.first;
  if (pin.length < 4 || pin.length > 6) {
    print('PIN must be 4 to 6 digits.');
    exit(64);
  }
  final hash = BCrypt.hashpw(pin, BCrypt.gensalt(logRounds: 12));
  final secret = List<int>.generate(48, (i) =>
      (DateTime.now().microsecondsSinceEpoch + i * 37) % 256)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  print('# Copy these to your Mac Studio env (or LaunchAgent EnvironmentVariables):');
  print('export BR_PIN_BCRYPT_HASH=\'$hash\'');
  print('export BR_JWT_SECRET=\'$secret\'');
}
