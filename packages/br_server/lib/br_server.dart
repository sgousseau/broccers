/// br_server — Backend Dart shelf pour Broccers.
library br_server;

export 'src/config.dart';
export 'src/storage/sqlite_broc_repository.dart';
export 'src/auth/pin_auth_service.dart';
export 'src/adapters/pdf_dart_menu_renderer.dart';
export 'src/adapters/claude_cli_question.dart';
export 'src/handlers/api_router.dart';
export 'src/handlers/command_handler.dart';
export 'src/server_builder.dart';
