# Helyi Idegenvezető (iOS)

Egy iOS-alkalmazás, ami a helyzeted alapján **szóban, magyarul** mesél a közeli
látnivalókról: mi az, mikor épült, ki építtette, és milyen történelmi események,
történetek kötődnek hozzá. **Háttérben is fut**, így közben a Térkép, a Google Maps
vagy a Waze lehet az előtérben. Felolvasás közben a navigáció hangját csak lehalkítja,
nem állítja le.

## Hogyan működik

```
GPS (háttérben is)  →  Wikipédia geosearch: közeli cikkek  →  legjobb jelölt
      ↑                                                            │
      │                         a cikk szövege (tényszerű forrás)  ▼
      └── következő hely  ←  felolvasás (AVSpeech, hu-HU)  ←  Claude: szóbeli ismertető
```

1. **`LocationService`** – folyamatos helyzet, 40 méterenként frissül, háttérben is
   (`UIBackgroundModes: location`).
2. **`WikipediaService`** – a magyar Wikipédiából lekéri a közeli helyeket (külföldön,
   ha nincs magyar találat, az angolból), majd a kiválasztott cikk szövegét.
3. **`TourGuide`** – kiválasztja a következő helyet: a legközelebbit, amiről még nem
   meséltünk; haladás közben az előtted lévők előnyt kapnak, a mögötted lévők hátrányt.
4. **`ClaudeService`** – a cikkszövegből a Claude (`claude-opus-5-5`) szóban elmondható,
   120–200 szavas ismertetőt ír. Csak a forrásban szereplő tényekre támaszkodhat, így nem
   talál ki évszámokat. Az érdektelen helyeket (buszmegálló, átlagos utca) kihagyja.
   Megmondja az irányt is („előtted jobbra”, „északra”).
5. **`SpeechService`** – magyar hangon felolvassa (`.duckOthers` +
   `.interruptSpokenAudioAndMixWithOthers`), utána visszaadja a hangerőt a navigációnak.

A már elmondott helyeket megjegyzi, így ugyanarról nem mesél kétszer.

## Futtatás

Kell hozzá egy Mac Xcode 15+-szal és egy iPhone (iOS 17+).

```bash
brew install xcodegen
cd HelyiIdegenvezeto
xcodegen generate
open HelyiIdegenvezeto.xcodeproj
```

Xcode-ban: *Signing & Capabilities* → válaszd ki a saját Teamedet (ingyenes Apple ID is
jó), majd futtasd a telefonodon.

Az appban: ⚙️ Beállítások → írd be a Claude API-kulcsodat
([platform.claude.com](https://platform.claude.com)) → **Indítás**. A helymeghatározásnál
válaszd a **„Mindig”** engedélyt, hogy háttérben is működjön.

**Tipp:** sokkal természetesebb a hang, ha letöltesz egy jobb minőségű magyar hangot:
*Beállítások › Kisegítő lehetőségek › Felolvasott tartalom › Hangok › Magyar*. Az app
automatikusan a legjobb elérhetőt használja.

Szimulátorban is kipróbálható: *Features › Location › City Run / Freeway Drive*, vagy
egy saját GPX-fájl.

## Beállítások

| Beállítás | Jelentés |
|---|---|
| Keresési sugár | Milyen messze lévő helyekről meséljen (séta: 200–500 m, autó: 1–3 km) |
| Részletesség | A Claude `effort` szintje: *Gyors* (`low`, ajánlott vezetéshez), *Közepes*, *Alapos* |
| Beszédtempó | A felolvasás sebessége |

## Költség és biztonság

- Egy ismertető nagyjából 3–4 ezer bemeneti és néhány száz kimeneti token – a
  `claude-opus-5-5` árazásával ez kb. 1–3 cent helyenként.
- Az API-kulcs a Kulcskarikában tárolódik. **Saját használatra ez rendben van, de ha
  az App Store-ba tennéd**, ne a kulcs legyen az appban: készíts egy kis saját szervert
  (proxy), ami a kulcsot tárolja és továbbítja a kéréseket, és az app azt hívja.

## Továbbfejlesztési ötletek

- Hangos ismertető minőségének javítása felhős TTS-sel (természetesebb hang).
- CarPlay-támogatás (külön Apple-jogosultság kell hozzá).
- Kedvenc témák (pl. csak templomok, várak, II. világháború) beállítása.
- Offline mód: az útvonal mentén előre letöltött ismertetők.
- Kérdezés hanggal („mesélj még erről”).
