/// Liste officielle des 14 allergènes majeurs (règlement INCO UE n° 1169/2011).
enum SgAllergen {
  gluten('Gluten'),
  crustaceans('Crustacés'),
  eggs('Œufs'),
  fish('Poisson'),
  peanuts('Arachides'),
  soy('Soja'),
  dairy('Lait'),
  treeNuts('Fruits à coque'),
  celery('Céleri'),
  mustard('Moutarde'),
  sesame('Sésame'),
  sulfites('Sulfites'),
  lupin('Lupin'),
  molluscs('Mollusques');

  final String label;
  const SgAllergen(this.label);
}
