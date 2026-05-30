# Changelog — br_cli

## [0.1.0] — 2026-05-30
### Added
- CLI `br` (`bin/br.dart`) via args.CommandRunner.
- Commands : `br auth <pin>`, `br health`, `br cmd <command...>` (proxy vers /api/command), `br pdf <card-id> [--out path]` (download PDF).
- HTTP client minimal avec JWT cache `~/.broccers/cli-jwt`.

### MIGRATE LATER
- Passer à sg_cli framework (`SgCliCommand`, `SgCommandResult`, `SgCommandGroup`).
- Sous-commandes typées (employee/shift/break/menu/...) au lieu du proxy générique.
