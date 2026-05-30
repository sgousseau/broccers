/// Port pour fournir la date courante. Injectable pour testabilité.
///
/// Implémentation système : `SystemClockPort` (DateTime.now()).
/// Implémentation test : `FixedClockPort` (DateTime fixe ou avançable).
abstract interface class SgClockPort {
  DateTime now();
}

/// Implémentation système.
class SystemClockPort implements SgClockPort {
  const SystemClockPort();
  @override
  DateTime now() => DateTime.now().toUtc();
}
