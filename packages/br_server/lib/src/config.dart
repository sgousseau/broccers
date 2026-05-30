import 'dart:io';

class BrServerConfig {
  final String host;
  final int port;
  final String dataDir;
  final String dbPath;
  final String pdfExportsDir;
  final String pinHashEnvName;
  final String jwtSecretEnvName;
  final String claudeCliPath;
  final String corsOriginRegex;

  const BrServerConfig({
    required this.host,
    required this.port,
    required this.dataDir,
    required this.dbPath,
    required this.pdfExportsDir,
    required this.pinHashEnvName,
    required this.jwtSecretEnvName,
    required this.claudeCliPath,
    required this.corsOriginRegex,
  });

  factory BrServerConfig.fromEnv() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dataDir =
        Platform.environment['BR_DATA_DIR'] ?? '$home/.broccers';
    return BrServerConfig(
      host: Platform.environment['BR_HOST'] ?? '0.0.0.0',
      port: int.tryParse(Platform.environment['BR_PORT'] ?? '') ?? 8444,
      dataDir: dataDir,
      dbPath: Platform.environment['BR_DB_PATH'] ?? '$dataDir/broc.db',
      pdfExportsDir:
          Platform.environment['BR_PDF_DIR'] ?? '$dataDir/pdf_exports',
      pinHashEnvName: 'BR_PIN_BCRYPT_HASH',
      jwtSecretEnvName: 'BR_JWT_SECRET',
      claudeCliPath:
          Platform.environment['BR_CLAUDE_CLI'] ?? '/usr/local/bin/claude',
      corsOriginRegex: Platform.environment['BR_CORS_REGEX'] ??
          r'^https?://([a-zA-Z0-9-]+\.tail-[a-z0-9]+\.ts\.net|127\.0\.0\.1|localhost)(:\d+)?$',
    );
  }

  void ensureDirectories() {
    Directory(dataDir).createSync(recursive: true);
    Directory(pdfExportsDir).createSync(recursive: true);
  }
}
