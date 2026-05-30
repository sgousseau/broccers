import 'dart:io';

import 'package:br_server/br_server.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    final ts = rec.time.toIso8601String();
    stdout.writeln('[$ts] ${rec.level.name} ${rec.loggerName}: ${rec.message}');
    if (rec.error != null) stdout.writeln('  error: ${rec.error}');
  });

  final config = BrServerConfig.fromEnv();
  final server = await BrServerBuilder.start(config);

  ProcessSignal.sigint.watch().listen((_) async {
    Logger.root.info('🛑 SIGINT, shutting down');
    await server.close(force: false);
    exit(0);
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    Logger.root.info('🛑 SIGTERM, shutting down');
    await server.close(force: false);
    exit(0);
  });
}
