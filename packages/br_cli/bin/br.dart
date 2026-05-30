import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:br_cli/br_cli.dart';

Future<void> main(List<String> args) async {
  final baseUrl = Uri.parse(
    Platform.environment['BR_SERVER_URL'] ?? 'http://127.0.0.1:8444',
  );
  final api = BrApiClient(baseUrl: baseUrl);

  final runner = CommandRunner<int>(
    'br',
    'Broccers CLI — auth, employee, shift, break, menu, shopping, ask, print.\n'
        'Server : \$BR_SERVER_URL (default http://127.0.0.1:8444)',
  )
    ..addCommand(_HealthCmd(api))
    ..addCommand(_AuthCmd(api))
    ..addCommand(_CmdCmd(api))
    ..addCommand(_PdfCmd(api));

  try {
    final exitCode = await runner.run(args) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  }
}

class _HealthCmd extends Command<int> {
  @override
  String get name => 'health';
  @override
  String get description => 'Ping le serveur';
  final BrApiClient api;
  _HealthCmd(this.api);
  @override
  Future<int> run() async {
    final r = await api.health();
    return r.when(
      success: (body) {
        print('OK — ${body['service']} v${body['version']} now=${body['now']}');
        return 0;
      },
      failure: (e) {
        print('FAIL — ${e.message}');
        return 1;
      },
    );
  }
}

class _AuthCmd extends Command<int> {
  @override
  String get name => 'auth';
  @override
  String get description => 'Authentifie via PIN (cache JWT dans ~/.broccers/cli-jwt)';
  final BrApiClient api;
  _AuthCmd(this.api);
  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('Usage: br auth <pin>');
      return 64;
    }
    final r = await api.authenticate(rest.first);
    return r.when(
      success: (_) {
        print('OK — JWT cached.');
        return 0;
      },
      failure: (e) {
        print('FAIL — ${e.message}');
        return 1;
      },
    );
  }
}

class _CmdCmd extends Command<int> {
  @override
  String get name => 'cmd';
  @override
  String get description =>
      'Exécute une commande TestControlServer (proxy /api/command)';
  final BrApiClient api;
  _CmdCmd(this.api);
  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('Usage: br cmd <command-string>\n'
          'Ex   : br cmd "menu create-sample --name \\"Carte du jour\\""');
      return 64;
    }
    final r = await api.command(rest.join(' '));
    return r.when(
      success: (resp) {
        print(const JsonEncoder.withIndent('  ').convert(resp));
        return resp['type'] == 'success' ? 0 : 1;
      },
      failure: (e) {
        print('FAIL — ${e.message}');
        return 1;
      },
    );
  }
}

class _PdfCmd extends Command<int> {
  @override
  String get name => 'pdf';
  @override
  String get description => 'Télécharge un PDF carte';
  final BrApiClient api;
  _PdfCmd(this.api) {
    argParser.addOption('out', help: 'Chemin de sortie', defaultsTo: './menu.pdf');
  }
  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('Usage: br pdf <card-id> [--out path]');
      return 64;
    }
    final r = await api.downloadPdf(rest.first);
    return r.when(
      success: (bytes) {
        final out = argResults!['out'] as String;
        File(out).writeAsBytesSync(bytes);
        print('PDF saved : $out (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
        return 0;
      },
      failure: (e) {
        print('FAIL — ${e.message}');
        return 1;
      },
    );
  }
}
