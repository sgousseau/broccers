/// Type d'une carte Broccers. Plusieurs cartes peuvent coexister (1 publiée par kind).
enum SgMenuCardKind {
  food('Plats'),
  drinks('Boissons'),
  wine('Vins'),
  dessert('Desserts'),
  menu('Menus / Formules'),
  brunch('Brunch'),
  daily('Carte du jour'),
  other('Autre');

  final String label;
  const SgMenuCardKind(this.label);

  static SgMenuCardKind fromName(String n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return SgMenuCardKind.other;
  }
}
