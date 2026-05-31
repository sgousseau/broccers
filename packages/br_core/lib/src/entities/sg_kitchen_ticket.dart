import 'package:meta/meta.dart';

/// État d'un ticket cuisine dans son cycle de vie.
enum SgKitchenTicketStatus {
  voiceDraft, // tout juste parsé depuis voix, attendant validation serveur
  pendingKitchen, // envoyé en cuisine, en attente prise en charge
  inProgress, // cuisine a démarré
  ready, // prêt à servir
  served, // servi en salle
  cancelled, // annulé
}

/// État d'un item dans un ticket.
enum SgKitchenItemStatus {
  pending, // pas encore commencé
  cooking, // en cours (cuisson démarrée)
  ready, // prêt à dresser
  served, // servi
  cancelled, // annulé / 86
}

/// Un item dans un ticket cuisine. Référence optionnellement un SgMenuItem.
@immutable
class SgKitchenTicketItem {
  final String id;
  final String ticketId;
  final String? menuItemId;
  final String label;
  final int quantity;
  final List<String> modifiers;
  final SgKitchenItemStatus status;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? servedAt;

  const SgKitchenTicketItem({
    required this.id,
    required this.ticketId,
    required this.label,
    required this.quantity,
    required this.modifiers,
    required this.status,
    this.menuItemId,
    this.notes,
    this.startedAt,
    this.readyAt,
    this.servedAt,
  });

  SgKitchenTicketItem copyWith({
    String? id,
    String? ticketId,
    String? menuItemId,
    String? label,
    int? quantity,
    List<String>? modifiers,
    SgKitchenItemStatus? status,
    String? notes,
    DateTime? startedAt,
    DateTime? readyAt,
    DateTime? servedAt,
  }) =>
      SgKitchenTicketItem(
        id: id ?? this.id,
        ticketId: ticketId ?? this.ticketId,
        menuItemId: menuItemId ?? this.menuItemId,
        label: label ?? this.label,
        quantity: quantity ?? this.quantity,
        modifiers: modifiers ?? this.modifiers,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        startedAt: startedAt ?? this.startedAt,
        readyAt: readyAt ?? this.readyAt,
        servedAt: servedAt ?? this.servedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_id': ticketId,
        if (menuItemId != null) 'menu_item_id': menuItemId,
        'label': label,
        'quantity': quantity,
        'modifiers': modifiers,
        'status': status.name,
        if (notes != null) 'notes': notes,
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (readyAt != null) 'ready_at': readyAt!.toIso8601String(),
        if (servedAt != null) 'served_at': servedAt!.toIso8601String(),
      };

  factory SgKitchenTicketItem.fromJson(Map<String, dynamic> j) =>
      SgKitchenTicketItem(
        id: j['id'] as String,
        ticketId: j['ticket_id'] as String,
        menuItemId: j['menu_item_id'] as String?,
        label: j['label'] as String,
        quantity: j['quantity'] as int? ?? 1,
        modifiers: ((j['modifiers'] as List<dynamic>?) ?? const [])
            .cast<String>(),
        status: SgKitchenItemStatus.values
            .firstWhere((s) => s.name == j['status']),
        notes: j['notes'] as String?,
        startedAt: j['started_at'] != null
            ? DateTime.parse(j['started_at'] as String)
            : null,
        readyAt: j['ready_at'] != null
            ? DateTime.parse(j['ready_at'] as String)
            : null,
        servedAt: j['served_at'] != null
            ? DateTime.parse(j['served_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgKitchenTicketItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgKitchenTicketItem($quantity× "$label"${modifiers.isNotEmpty ? " [${modifiers.join(",")}]" : ""}, ${status.name})';
}

/// Un ticket cuisine. Créé depuis voix ou saisie manuelle par un serveur.
@immutable
class SgKitchenTicket {
  final String id;
  final int? tableNumber;
  final String? tableLabel;
  final SgKitchenTicketStatus status;
  final List<SgKitchenTicketItem> items;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? sentToKitchenAt;
  final DateTime? completedAt;
  final String? voiceTranscript;

  const SgKitchenTicket({
    required this.id,
    required this.status,
    required this.items,
    required this.createdBy,
    required this.createdAt,
    this.tableNumber,
    this.tableLabel,
    this.sentToKitchenAt,
    this.completedAt,
    this.voiceTranscript,
  });

  factory SgKitchenTicket.fromVoice({
    required String id,
    required List<SgKitchenTicketItem> items,
    required String createdBy,
    required DateTime createdAt,
    required String voiceTranscript,
    int? tableNumber,
    String? tableLabel,
  }) =>
      SgKitchenTicket(
        id: id,
        status: SgKitchenTicketStatus.voiceDraft,
        items: items,
        createdBy: createdBy,
        createdAt: createdAt,
        tableNumber: tableNumber,
        tableLabel: tableLabel,
        voiceTranscript: voiceTranscript,
      );

  SgKitchenTicket sendToKitchen({required DateTime at}) => copyWith(
        status: SgKitchenTicketStatus.pendingKitchen,
        sentToKitchenAt: at,
      );

  SgKitchenTicket complete({required DateTime at}) => copyWith(
        status: SgKitchenTicketStatus.served,
        completedAt: at,
      );

  SgKitchenTicket copyWith({
    String? id,
    int? tableNumber,
    String? tableLabel,
    SgKitchenTicketStatus? status,
    List<SgKitchenTicketItem>? items,
    String? createdBy,
    DateTime? createdAt,
    DateTime? sentToKitchenAt,
    DateTime? completedAt,
    String? voiceTranscript,
  }) =>
      SgKitchenTicket(
        id: id ?? this.id,
        tableNumber: tableNumber ?? this.tableNumber,
        tableLabel: tableLabel ?? this.tableLabel,
        status: status ?? this.status,
        items: items ?? this.items,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        sentToKitchenAt: sentToKitchenAt ?? this.sentToKitchenAt,
        completedAt: completedAt ?? this.completedAt,
        voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (tableNumber != null) 'table_number': tableNumber,
        if (tableLabel != null) 'table_label': tableLabel,
        'status': status.name,
        'items': items.map((i) => i.toJson()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        if (sentToKitchenAt != null) 'sent_to_kitchen_at': sentToKitchenAt!.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
      };

  factory SgKitchenTicket.fromJson(Map<String, dynamic> j) => SgKitchenTicket(
        id: j['id'] as String,
        tableNumber: j['table_number'] as int?,
        tableLabel: j['table_label'] as String?,
        status: SgKitchenTicketStatus.values
            .firstWhere((s) => s.name == j['status']),
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((i) => SgKitchenTicketItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        sentToKitchenAt: j['sent_to_kitchen_at'] != null
            ? DateTime.parse(j['sent_to_kitchen_at'] as String)
            : null,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        voiceTranscript: j['voice_transcript'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgKitchenTicket && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgKitchenTicket($id, table=$tableNumber, ${items.length} items, ${status.name})';
}
