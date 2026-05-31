import 'dart:typed_data';

import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_kitchen_ticket.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../ports/sg_voice_parser_port.dart';
import '../result.dart';

/// Parse une commande (audio ou texte) en SgKitchenTicket draft.
/// Le ticket est créé en statut `voiceDraft`, à valider par le serveur avant envoi cuisine.
class ParseVoiceOrderUseCase {
  final SgBrocRepositoryPort _repo;
  final SgVoiceParserPort _parser;
  final SgClockPort _clock;
  final String Function() _ticketIdGenerator;
  final String Function() _itemIdGenerator;
  final String Function() _eventIdGenerator;

  const ParseVoiceOrderUseCase({
    required SgBrocRepositoryPort repository,
    required SgVoiceParserPort parser,
    required SgClockPort clock,
    required String Function() ticketIdGenerator,
    required String Function() itemIdGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _parser = parser,
        _clock = clock,
        _ticketIdGenerator = ticketIdGenerator,
        _itemIdGenerator = itemIdGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgKitchenTicket, SgFailure>> call({
    Uint8List? audioBytes,
    String? audioMimeType,
    String? textFallback,
    int? tableNumber,
    String createdBy = 'server',
  }) async {
    final menuRes = await _repo.getCurrentPublishedMenuCard();
    final menu = menuRes.valueOrNull;
    final menuItems = menu?.items ?? const [];

    final parseRes = await _parser.parse(
      audioBytes: audioBytes,
      audioMimeType: audioMimeType,
      textFallback: textFallback,
      menuContext: menuItems,
      tableNumber: tableNumber,
    );
    return parseRes.when(
      success: (out) async {
        final ticketId = 'tk-${_ticketIdGenerator()}';
        final items = out.items
            .map((i) => i.copyWith(
                  id: 'tki-${_itemIdGenerator()}',
                  ticketId: ticketId,
                ))
            .toList();
        final ticket = SgKitchenTicket.fromVoice(
          id: ticketId,
          items: items,
          createdBy: createdBy,
          createdAt: _clock.now(),
          voiceTranscript: out.transcript,
          tableNumber: out.tableNumber ?? tableNumber,
        );
        final stored = await _repo.createKitchenTicket(ticket);
        return stored.when(
          success: (t) async {
            await _repo.logEvent(SgEventJournalEntry(
              id: _eventIdGenerator(),
              at: _clock.now(),
              actor: createdBy,
              action: 'ticket.voice_parsed',
              target: 'ticket:${t.id}',
              payload: {
                'items_count': t.items.length,
                'table': t.tableNumber,
                'engine': _parser.engineId,
                'transcript_chars': out.transcript.length,
                if (out.engineNote != null) 'engine_note': out.engineNote,
              },
            ));
            return Success<SgKitchenTicket, SgFailure>(t);
          },
          failure: (e) async => Failure<SgKitchenTicket, SgFailure>(e),
        );
      },
      failure: (e) async => Failure<SgKitchenTicket, SgFailure>(e),
    );
  }
}
