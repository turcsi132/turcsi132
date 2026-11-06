# Könnyű Horgász – egygombos horgászat WoW-hoz

Egyetlen gombbal horgászhatsz:

1. Megnyomod a gombot (alapból **F**), és a karakter bedobja a csalit.
2. Amikor kapás van (csobbanás hallatszik, az úszó megmozdul), megnyomod **ugyanazt a gombot**,
   és a karakter kihúzza a halat. Az automatikus zsákmányolás be van kapcsolva, így a hal
   egyenesen a táskádba kerül.
3. Újra megnyomod, és megint bedobja a csalit.

Nem kell célozni, és nem kell az úszóra kattintani egérrel.

## Telepítés

Másold a `KonnyuHorgasz` mappát ide:

```
World of Warcraft\_<verzió>_\Interface\AddOns\KonnyuHorgasz
```

(pl. `_classic_era_`, `_classic_` vagy `_retail_`). Ha a szerververzióhoz nem illik a TOC
fájl `Interface` száma, a karakterválasztóban kapcsold be a „Load out of date AddOns” opciót.

## Használat

| Parancs | Mit csinál |
|---|---|
| `/horgasz` (vagy `/kh`) | horgász mód be/ki |
| `/horgasz gomb SPACE` | másik gomb beállítása (pl. `F`, `SPACE`, `BUTTON3`, `MOUSEWHEELUP`) |
| `/horgasz hang` | hangos kapás mód be/ki: effektek hangosabbak, zene és környezeti zajok némítva, hogy jól halld a csobbanást |

Kikapcsoláskor minden átállított beállítás (hang, automatikus zsákmányolás, célzás)
visszaáll az eredeti értékére. A gomb csak horgász módban horgászik, máskor az eredeti funkciója marad.

## Miért kell mégis megnyomni a gombot?

A WoW addon-rendszere szándékosan nem engedi, hogy egy addon magától varázsoljon vagy
tárgyakkal lépjen kapcsolatba. Minden ilyen művelethez a játékos gombnyomása kell, így
teljesen önműködő horgászat addonnal nem lehetséges. Külső programmal (bottal) meg lehetne
csinálni, de az sérti a játék szabályzatát, és a fiók kitiltásával járhat.
