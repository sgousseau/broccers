# Spec analyst — Carte dynamique + PDF imprimable

## Schéma `SgMenuCard`

```dart
class SgMenuCard {
  String id;
  String name;            // "Carte de Printemps"
  int version;            // auto-incrément à chaque publication
  DateTime? publishedAt;  // null = brouillon
  List<SgMenuCategory> categories;
  List<SgMenuItem> items;
}

class SgMenuCategory {
  String id;
  String cardId;
  String name;            // "Entrées", "Plats", "Vins"
  int sortOrder;
}

class SgMenuItem {
  String id;
  String cardId;
  String categoryId;
  String name;            // "Tartare de bœuf"
  String? description;
  int priceCents;
  bool available;
  Set<SgAllergen> allergens;
  int sortOrder;
}

enum SgAllergen {
  gluten, dairy, eggs, peanuts, treeNuts, soy, fish, shellfish,
  celery, mustard, sesame, sulfites, lupin, molluscs,
}
```

## UseCase `PublishMenuCardUseCase`
1. Reçoit `SgMenuCard` (status draft = `publishedAt == null`)
2. Validation : nom non vide, au moins 1 catégorie, au moins 1 item par catégorie publiée
3. Incrémente `version` (atomic sur le SqliteBrocRepository)
4. Set `publishedAt = now()`
5. Persiste + marque ancienne version `superseded`

## UseCase `ExportMenuCardPdfUseCase`
1. Charge `SgMenuCard` par `id`
2. Appelle `SgPdfRendererPort.render(card)` → `Uint8List`
3. Stocke fichier `~/.broccers/pdf_exports/YYYY/MM/DD/menu_v<N>_<timestamp>.pdf`
4. Persiste `SgPdfExport` (lineage Source/Derivation)
5. Retourne `Result<SgPdfExport, SgFailure>`

## Port `SgPdfRendererPort`

```dart
abstract interface class SgPdfRendererPort {
  String get engineId; // "pdf-dart-2.4"
  Future<Result<Uint8List, SgFailure>> render(SgMenuCard card);
}
```

Adapter v1 : `PdfDartMenuRenderer` (package `pdf`).
Adapter futur : `ChromiumHtmlMenuRenderer` (HTML/CSS riche).

## Layout PDF A4 (210 × 297 mm)

```
┌──────────────────────────────────────────┐
│            BRASSERIE BROC                │  ← Header bandeau
│      Puces du Canal — Villeurbanne       │  ← typo serif élégante
├──────────────────────────────────────────┤
│  ENTRÉES                                  │  ← Category title bold
│  ─────                                     │
│  Tartare de bœuf                  12 €   │  ← name + price
│  Bœuf coupé au couteau, condiments        │  ← description italic
│  · gluten · moutarde                      │  ← allergens minuscule
│                                           │
│  Soupe à l'oignon gratinée        9 €    │
│  ...                                       │
├──────────────────────────────────────────┤
│  PLATS                                    │
│  ─────                                     │
│  ...                                       │
├──────────────────────────────────────────┤
│  Prix nets, service compris               │  ← Footer
│  Allergènes sur demande                   │
│  Carte v3 — imprimée le 30/05/2026 14h32  │  ← traçabilité
└──────────────────────────────────────────┘
```

## Typographie v1
- Header : `Helvetica-Bold` 24 pt
- Sous-header : `Helvetica` 11 pt italic
- Catégorie : `Helvetica-Bold` 14 pt + underline
- Item nom : `Helvetica-Bold` 11 pt
- Item description : `Helvetica-Oblique` 9 pt
- Allergènes : `Helvetica` 7 pt
- Footer : `Helvetica` 8 pt

Le package `pdf` Dart natif fournit Helvetica par défaut (Latin1). Pour serif/script custom : ajouter font asset (v0.2).

## Multi-page
- Si > N items, paginer auto
- Catégorie ne se casse PAS au milieu (orphan/widow control)
- Numérotation page bas droite : "1/2"

## Décisions

- **v1** : 1 layout fixe (élégant simple). v0.2 : templates configurables.
- **Allergènes** : icônes ou texte ? → Texte pour v1 (UTF-8, pas d'asset à gérer).
- **Format** : A4 portrait par défaut. A3, A5, paysage = v0.2.
- **Couleur** : N&B v1 (économe imprimante restau). Couleur = v0.2.
