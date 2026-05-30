import 'package:meta/meta.dart';

/// Question posée à Claude + réponse + snapshot du contexte au moment de l'ask.
@immutable
class SgQuestion {
  final String id;
  final DateTime askedAt;
  final String question;
  final Map<String, dynamic> contextSnapshot;
  final String? answer;
  final String engine;
  final DateTime? answeredAt;

  const SgQuestion({
    required this.id,
    required this.askedAt,
    required this.question,
    required this.contextSnapshot,
    required this.engine,
    this.answer,
    this.answeredAt,
  });

  SgQuestion withAnswer({required String text, required DateTime at}) =>
      copyWith(answer: text, answeredAt: at);

  SgQuestion copyWith({
    String? id,
    DateTime? askedAt,
    String? question,
    Map<String, dynamic>? contextSnapshot,
    String? answer,
    String? engine,
    DateTime? answeredAt,
  }) =>
      SgQuestion(
        id: id ?? this.id,
        askedAt: askedAt ?? this.askedAt,
        question: question ?? this.question,
        contextSnapshot: contextSnapshot ?? this.contextSnapshot,
        answer: answer ?? this.answer,
        engine: engine ?? this.engine,
        answeredAt: answeredAt ?? this.answeredAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'asked_at': askedAt.toIso8601String(),
        'question': question,
        'context_snapshot': contextSnapshot,
        if (answer != null) 'answer': answer,
        'engine': engine,
        if (answeredAt != null) 'answered_at': answeredAt!.toIso8601String(),
      };

  factory SgQuestion.fromJson(Map<String, dynamic> json) => SgQuestion(
        id: json['id'] as String,
        askedAt: DateTime.parse(json['asked_at'] as String),
        question: json['question'] as String,
        contextSnapshot:
            (json['context_snapshot'] as Map<String, dynamic>?) ?? const {},
        answer: json['answer'] as String?,
        engine: json['engine'] as String,
        answeredAt: json['answered_at'] != null
            ? DateTime.parse(json['answered_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgQuestion && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgQuestion($id, "${question.length > 30 ? "${question.substring(0, 30)}..." : question}"${answer != null ? " → answered" : ""})';
}
