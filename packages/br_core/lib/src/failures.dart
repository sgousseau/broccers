// MIGRATE LATER : remplacer par sg_core/SgFailure dès qu'il est pure-Dart.

import 'package:meta/meta.dart';

@immutable
sealed class SgFailure {
  final String message;
  final Object? cause;
  const SgFailure(this.message, {this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (cause: $cause)' : ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is SgFailure &&
          other.message == message);

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

// === Generic (alignés sg_core) ===

final class SgValidationFailure extends SgFailure {
  const SgValidationFailure(super.message, {super.cause});
}
final class SgDatabaseFailure extends SgFailure {
  const SgDatabaseFailure(super.message, {super.cause});
}
final class SgNetworkFailure extends SgFailure {
  const SgNetworkFailure(super.message, {super.cause});
}
final class SgNotFoundFailure extends SgFailure {
  const SgNotFoundFailure(super.message, {super.cause});
}
final class SgPermissionFailure extends SgFailure {
  const SgPermissionFailure(super.message, {super.cause});
}
final class SgFileSystemFailure extends SgFailure {
  const SgFileSystemFailure(super.message, {super.cause});
}
final class SgParseFailure extends SgFailure {
  const SgParseFailure(super.message, {super.cause});
}
final class SgUnexpectedFailure extends SgFailure {
  const SgUnexpectedFailure(super.message, {super.cause});
}

// === Broccers-specific ===

abstract base class SgBrocFailure extends SgFailure {
  const SgBrocFailure(super.message, {super.cause});
}

final class SgBrocAuthFailure extends SgBrocFailure {
  const SgBrocAuthFailure(super.message, {super.cause});
}

final class SgBrocPdfFailure extends SgBrocFailure {
  const SgBrocPdfFailure(super.message, {super.cause});
}

final class SgBrocQuestionFailure extends SgBrocFailure {
  const SgBrocQuestionFailure(super.message, {super.cause});
}

final class SgBrocComplianceFailure extends SgBrocFailure {
  const SgBrocComplianceFailure(super.message, {super.cause});
}

final class SgBrocKioskFailure extends SgBrocFailure {
  const SgBrocKioskFailure(super.message, {super.cause});
}

final class SgBrocStateFailure extends SgBrocFailure {
  const SgBrocStateFailure(super.message, {super.cause});
}

final class SgBrocHourlyRateFailure extends SgBrocFailure {
  const SgBrocHourlyRateFailure(super.message, {super.cause});
}

final class SgBrocConsumptionFailure extends SgBrocFailure {
  const SgBrocConsumptionFailure(super.message, {super.cause});
}
