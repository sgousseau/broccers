import 'dart:io';

import 'package:br_core/br_core.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

import 'adapters/claude_cli_question.dart';
import 'adapters/claude_voice_parser.dart';
import 'adapters/pdf_dart_menu_renderer.dart';
import 'auth/pin_auth_service.dart';
import 'config.dart';
import 'handlers/api_router.dart';
import 'handlers/command_handler.dart';
import 'storage/sqlite_broc_repository.dart';

class BrServerBuilder {
  static Future<HttpServer> start(BrServerConfig config) async {
    final log = Logger('br_server');

    config.ensureDirectories();

    final repo = SqliteBrocRepository.open(dbPath: config.dbPath);

    final pinHash = Platform.environment[config.pinHashEnvName] ?? '';
    final jwtSecret = Platform.environment[config.jwtSecretEnvName] ?? '';
    if (jwtSecret.isEmpty) {
      log.warning('${config.jwtSecretEnvName} empty — ephemeral JWT secret (won\'t survive restart)');
    }
    if (pinHash.isEmpty) {
      log.warning('${config.pinHashEnvName} empty — auth will fail until configured');
    }

    final auth = PinAuthService(
      db: repo.db,
      pinBcryptHash: pinHash,
      jwtSecret: jwtSecret.isEmpty ? PinAuthService.generateJwtSecret() : jwtSecret,
    );

    final pdf = const PdfDartMenuRenderer();
    final question = ClaudeCliQuestion(claudeCliPath: config.claudeCliPath);
    final voiceParser = ClaudeVoiceParser(
      claudeCliPath: config.claudeCliPath,
      whisperUrl: Platform.environment['BR_WHISPER_URL'],
    );

    final uuid = const Uuid();
    final clock = const SystemClockPort();
    DateTime now() => clock.now();
    String genId() => uuid.v4();

    final clockIn = ClockInUseCase(
      repository: repo,
      clock: clock,
      shiftIdGenerator: () => 'sh-${genId()}',
      segmentIdGenerator: () => 'seg-${genId()}',
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final clockOut = ClockOutUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final changeRole = ChangeRoleInShiftUseCase(
      repository: repo,
      clock: clock,
      segmentIdGenerator: () => 'seg-${genId()}',
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final setWeekly = SetWeeklyDefaultUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final setRoles = SetEmployeeRolesUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final startBreak = StartBreakUseCase(
      repository: repo,
      clock: clock,
      idGenerator: () => 'br-${genId()}',
    );
    final endBreak = EndBreakUseCase(repository: repo, clock: clock);
    final publishMenu = PublishMenuCardUseCase(repository: repo, clock: clock);
    final exportPdf = ExportMenuCardPdfUseCase(
      repository: repo,
      pdfRenderer: pdf,
      clock: clock,
      idGenerator: () => 'pdf-${genId()}',
    );
    final addShoppingItem = AddShoppingItemUseCase(
      repository: repo,
      clock: clock,
      idGenerator: () => 'si-${genId()}',
    );
    final checkShoppingItem = CheckShoppingItemUseCase(repository: repo, clock: clock);
    final askQuestion = AskQuestionUseCase(
      repository: repo,
      engine: question,
      clock: clock,
      idGenerator: () => 'q-${genId()}',
    );
    final setHourlyRate = SetHourlyRateUseCase(
      repository: repo,
      clock: clock,
      idGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final recordConsumption = RecordStaffConsumptionUseCase(
      repository: repo,
      clock: clock,
      idGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final computeShiftCost = ComputeShiftCostUseCase(
      repository: repo,
      clock: clock,
    );
    final archiveEmployee = ArchiveEmployeeUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final recordShiftTip = RecordShiftTipUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final generateBriefing = GenerateMorningBriefingUseCase(
      repository: repo,
      engine: question,
      clock: clock,
      idGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final generateOnboarding = GenerateOnboardingChecklistUseCase(
      repository: repo,
      engine: question,
      clock: clock,
      idGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final checkOnboardingItem = CheckOnboardingItemUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final parseVoiceOrder = ParseVoiceOrderUseCase(
      repository: repo,
      parser: voiceParser,
      clock: clock,
      ticketIdGenerator: () => genId(),
      itemIdGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final sendTicketToKitchen = SendTicketToKitchenUseCase(
      repository: repo,
      clock: clock,
      taskIdGenerator: () => genId(),
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final startCookingTask = StartCookingTaskUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );
    final completeCookingTask = CompleteCookingTaskUseCase(
      repository: repo,
      clock: clock,
      eventIdGenerator: () => 'evt-${genId()}',
    );

    final commands = BrCommandRegistry(
      config: config,
      repository: repo,
      question: question,
      pdf: pdf,
      clockIn: clockIn,
      clockOut: clockOut,
      startBreak: startBreak,
      endBreak: endBreak,
      publishMenu: publishMenu,
      exportPdf: exportPdf,
      addShoppingItem: addShoppingItem,
      checkShoppingItem: checkShoppingItem,
      askQuestion: askQuestion,
      changeRole: changeRole,
      setWeekly: setWeekly,
      setRoles: setRoles,
      setHourlyRate: setHourlyRate,
      recordConsumption: recordConsumption,
      computeShiftCost: computeShiftCost,
      archiveEmployee: archiveEmployee,
      recordShiftTip: recordShiftTip,
      generateBriefing: generateBriefing,
      generateOnboarding: generateOnboarding,
      checkOnboardingItem: checkOnboardingItem,
      parseVoiceOrder: parseVoiceOrder,
      sendTicketToKitchen: sendTicketToKitchen,
      startCookingTask: startCookingTask,
      completeCookingTask: completeCookingTask,
      uuid: uuid,
      now: now,
    );

    final router = BrApiRouter(
      changeRole: changeRole,
      setWeekly: setWeekly,
      setRoles: setRoles,
      auth: auth,
      repository: repo,
      commandRegistry: commands,
      clockIn: clockIn,
      clockOut: clockOut,
      startBreak: startBreak,
      endBreak: endBreak,
      publishMenu: publishMenu,
      exportPdf: exportPdf,
      addShoppingItem: addShoppingItem,
      checkShoppingItem: checkShoppingItem,
      askQuestion: askQuestion,
    );

    final pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware(config.corsOriginRegex))
        .addHandler(router.build());

    final server = await shelf_io.serve(pipeline, config.host, config.port);
    log.info('🍻 br_server up on http://${server.address.address}:${server.port}');
    log.info('   data dir : ${config.dataDir}');
    log.info('   pdf dir  : ${config.pdfExportsDir}');
    log.info('   claude   : ${config.claudeCliPath}');
    return server;
  }

  static Middleware _corsMiddleware(String originRegex) {
    final regex = RegExp(originRegex);
    return (Handler inner) {
      return (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders(req, regex));
        }
        final resp = await inner(req);
        return resp.change(headers: {
          ...resp.headers,
          ..._corsHeaders(req, regex),
        });
      };
    };
  }

  static Map<String, String> _corsHeaders(Request req, RegExp allowed) {
    final origin = req.headers['origin'];
    final allow = (origin != null && allowed.hasMatch(origin)) ? origin : '*';
    return {
      'access-control-allow-origin': allow,
      'access-control-allow-headers': 'authorization, content-type',
      'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'access-control-max-age': '600',
    };
  }
}
