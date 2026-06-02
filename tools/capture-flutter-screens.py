#!/usr/local/Cellar/python@3.13/3.13.2/Frameworks/Python.framework/Versions/3.13/bin/python3.13
"""
Capture screenshots de tous les écrans Flutter Broccers v0.8.0 via Playwright.

Pré-requis :
  pip install playwright (déjà via pipx)
  playwright install chromium

Usage :
  python3 tools/capture-flutter-screens.py [--out DIR] [--token TOKEN]
"""

import asyncio
import sys
import os
import time
from pathlib import Path

from playwright.async_api import async_playwright

WEB_URL = "http://127.0.0.1:8766"
SERVER_URL = "http://127.0.0.1:8444"
OUT_DIR = Path("/Users/sgo/Code/broccers/docs/test-assets")
TOKEN_FILE = Path("/tmp/broccers-tests/token.txt")

# Onglets à capturer dans l'ordre de la NavigationBar
TABS = [
    ("flutter_personnel",     0, "Personnel & RH"),
    ("flutter_kitchen",       1, "Cuisine connectée"),
    ("flutter_menu",          2, "Cartes & menus"),
    ("flutter_shopping",      3, "Achats"),
    ("flutter_question",      4, "Question IA"),
    ("flutter_journal",       5, "Journal d'audit"),
    ("flutter_costs",         6, "Coûts & paie"),
    ("flutter_waste",         7, "Pertes"),
    ("flutter_tables",        8, "Tables QR"),
    ("flutter_settings",      9, "Paramètres"),
    ("flutter_admin",        10, "Admin (super-admin)"),
]


async def capture():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    token = TOKEN_FILE.read_text().strip() if TOKEN_FILE.exists() else None
    if not token:
        print("✗ Token manquant. Lance d'abord les tests API.")
        sys.exit(1)

    print(f"→ Token (preview) : {token[:30]}…")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            device_scale_factor=1,
        )

        # Inject JWT in localStorage AVANT que Flutter ne boot.
        # shared_preferences web préfixe les clés par 'flutter.' et sérialise les
        # String en JSON-stringified (donc avec guillemets autour).
        # On essaie 4 variantes pour couvrir les versions shared_preferences.
        await context.add_init_script(f"""
            const t = "{token}";
            window.localStorage.setItem('flutter.br_jwt', JSON.stringify(t));
            window.localStorage.setItem('br_jwt', t);
        """)

        page = await context.new_page()

        # === STEP 1 : login screen — capturer SANS injection ===
        print("→ Capturing flutter_login (sans auth)")
        await page.goto(WEB_URL, wait_until="networkidle")
        await page.evaluate("""
            localStorage.removeItem('flutter.br_jwt');
            localStorage.removeItem('br_jwt');
        """)
        await page.reload(wait_until="networkidle")
        await asyncio.sleep(7)  # Flutter Web boot ~5-8s
        await page.screenshot(path=str(OUT_DIR / "flutter_login.png"), full_page=False)
        print(f"  ✓ flutter_login.png ({(OUT_DIR / 'flutter_login.png').stat().st_size} bytes)")

        # === STEP 2 : auth via UI (login screen avec champ PIN + bouton) ===
        # Plus fiable que d'injecter localStorage car bypasse l'init de Flutter.
        # Le PIN par défaut est 1234.
        print("→ Login via UI (PIN 1234)")
        # Flutter Web utilise un champ HTML invisible au-dessus du canvas pour les
        # TextField. On clique d'abord au milieu de l'écran pour trouver le champ,
        # puis on tape le PIN, puis Enter.
        # Position approximative du champ PIN : centre vertical, légèrement au-dessus du milieu
        await page.mouse.click(720, 460)
        await asyncio.sleep(0.5)
        await page.keyboard.type("1234", delay=80)
        await asyncio.sleep(0.3)
        await page.keyboard.press("Enter")
        await asyncio.sleep(5)  # attendre auth + navigation vers HomeShell

        # === STEP 3 : capture each tab via NavigationBar ===
        # Flutter's NavigationBar destinations sont des widgets — pour cliquer,
        # on cible par index visuel. NavigationBar est au bottom du viewport.
        for name, idx, label in TABS:
            print(f"→ Capturing {name} (tab {idx} — {label})")
            try:
                # NavigationBar prend toute la largeur en bas
                # Chaque destination occupe 1/11 de la largeur
                viewport_w = 1440
                viewport_h = 900
                n_tabs = len(TABS)
                tab_w = viewport_w / n_tabs
                # NavigationBar est ~80px de haut, on clique au milieu
                x = (idx + 0.5) * tab_w
                y = viewport_h - 40

                await page.mouse.click(x, y)
                await asyncio.sleep(2.5)  # attendre que l'onglet se charge

                # full_page=False car Flutter Web gère son propre scroll dans canvas
                await page.screenshot(
                    path=str(OUT_DIR / f"{name}.png"),
                    full_page=False,
                )
                size = (OUT_DIR / f"{name}.png").stat().st_size
                print(f"  ✓ {name}.png ({size} bytes)")
            except Exception as e:
                print(f"  ✗ {name} FAILED: {e}")

        await browser.close()


if __name__ == "__main__":
    print("=== Broccers Flutter screenshots via Playwright ===")
    print(f"Web URL    : {WEB_URL}")
    print(f"Output dir : {OUT_DIR}")
    print()
    asyncio.run(capture())
    print()
    print("=== Done ===")
    print(f"\nFichiers générés :")
    for f in sorted(OUT_DIR.glob("flutter_*.png")):
        print(f"  {f.stat().st_size:>10} bytes  {f.name}")
