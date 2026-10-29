# Trauma Village — Art Bible v0.1

Kaszubska wieś, lata 90. Survival horror w estetyce PS2. Dokument źródłowy dla
wszystkich assetów graficznych. Obowiązuje `artist`, `level-designer` i
`programmer` przy shaderach.

## 1. Kierunek

- Realizm pamięciowy, nie fotorealizm: wszystko wygląda jak z taniej płyty PS2
  z 2003 roku, nie jak współczesny render.
- Brud, wilgoć, zmęczenie materiału. Wieś nie jest idylliczna ani turystyczna.
- Kolory zgaszone, jakby na kliszy leżakowanej w piwnicy. Czerń nigdy nie jest
  czysta, biel nigdy nie jest białą.
- Horror wynika z ciszy, mgły i pustki, nie z gore. Krew i przemoc oszczędnie.
- Folklor kaszubski: drewno, kamień, mech, kapliczki, tkaniny, narzędzia rolnicze.
  Bez fantasy, bez rogów i ognia z oczu.

## 2. Paleta

Wspólna baza ~32 kolorów na scenę. Każdy asset mieści się w swojej kolumnie;
przejścia tonalne budujemy ditheringiem, nie gradientem.

### Dzień (overcast, flat)

| Rola | HEX | Uwaga |
|---|---|---|
| Niebo | `#A8B0A4` | szaro-zielone, bez błękitu |
| Mgła / dalszy plan | `#C6C9BE` | najjaśniejsza wartość sceny |
| Drewno suche | `#5B4A38` | ściany, płoty |
| Drewno mokre | `#3E332A` | narożniki, podcień |
| Mech / las | `#4A5334` | nasycenie maks. 25% |
| Piasek / droga | `#8C8066` | ubity grunt |
| Dach / papa | `#4E4A42` | neutralny grafit |
| Rdza / akcent | `#7A4A32` | tylko plamy, nie płaszczyzny |

### Zmierzch (ciepły horyzont, zimne cienie)

| Rola | HEX | Uwaga |
|---|---|---|
| Niebo góra | `#6E5A58` | brudny fiolet |
| Niebo horyzont | `#B08A6A` | ostatnie światło |
| Cień | `#3A3330` | wszystko w cieniu wpada w brąz |
| Okno zapalone | `#C9A15E` | jedyne ciepłe światło |
| Mgła | `#7D7268` | między ciepłem a zimnem |

### Noc (księżyc + latarka)

| Rola | HEX | Uwaga |
|---|---|---|
| Niebo | `#141A20` | granatowo-zielony |
| Cień | `#0C1014` | nie czysta czerń |
| Księżyc / rim | `#6F7F8C` | zimny, miękki |
| Latarka | `#C8B27A` | ciepły stożek, szybki falloff |
| Ostrzeżenie | `#5A1E1E` | krew, tylko punktowo |

### Zasady koloru

- Nasycenie sceny: max 35% (HSV S). Wyjątek: latarka i okna.
- Kontrast: dzień niski, zmierzch średni, noc wysoki tylko lokalnie.
- Zakaz czystych `#FF0000`, `#00FF00`, `#0000FF` i neonów.
- Postacie czytelne sylwetkowo: bohater jaśniejszy od tła, wróg ciemniejszy.

## 3. Światło

| Faza | Źródło | Cechy |
|---|---|---|
| Dzień | zachmurzone niebo | miękkie, kierunkowość ledwo widoczna, cienie krótkie i rozmyte, brak odbić lustrzanych |
| Zmierzch | słońce pod horyzontem | długie cienie, ciepły horyzont, zimne wnętrza, okna zapalane punktowo |
| Noc | księżyc + latarka | dominuje ciemność, stożek latarki 25–35°, falloff ~8 m, mgła ogranicza widoczność do 12 m (20 m w stożku latarki) |

Zasady:

- Zero HDR, bloomu, lens flare, chromatic aberration i ambient occlusion z
  nowoczesnego pipeline'u. Poświata tylko ręcznie malowana lub przez fog.
- Cienie twarde tylko w promieniu latarki; reszta miękka lub wypalona w teksturze.
- Wnętrza oświetlane punktowo (świeca, żarówka 40 W, piec). Światło nie może
  być równomierne — zostawiamy czarne kąty.
- Mgła jest narzędziem kompozycji: zasłania horyzont i tnie draw distance.

## 4. Materiały

Wszystkie matowe, wysoki roughness (0.75–0.95), specular minimalny.

| Materiał | Cechy | Rozdzielczość |
|---|---|---|
| Drewno (deski, bal) | słoje wzdłuż, pęknięcia, gwoździe, miejsca przetarte | 256 → 128 |
| Tynek / glina | łaty, rysy, odpadające płaty, odcisk palca | 256 → 128 |
| Dach (papa, strzecha) | pasy, zacieki, mech w szczelinach | 256 → 128 |
| Kamień / beton | ziarno, porost, wilgotne plamy | 256 → 128 |
| Ziemia / błoto | koleiny, kałuże, liście, kamienie | 256 → 128 |
| Ściółka leśna | igliwie, szyszki, butwiejące liście | 256 → 128 |
| Woda / jezioro | płaska, ciemna, delikatna fala, odbicie księżyca | 128, animowana |
| Tkanina | len, wełna, wyblakłe wzory, cerowanie | 128 |
| Metal | rdza, matowy, bez chromu i lustra | 128 |
| Skóra / twarz | matowa, niedoskonała, worki pod oczami, brud | 512 portret |

## 5. Zasady PS2

- **Rozdzielczość wewnętrzna:** 640×480 (4:3), skalowanie całkowite, opcjonalny
  letterbox. Finalne tekstury 128–256 px, portrety 512 px.
- **Paleta:** 16-bitowy feel, maks. ~32 kolory na scenę, dithering uporządkowany
  4×4 przy przejściach tonalnych.
- **Geometria:** niska liczba trójkątów, płaskie ściany, widoczne krawędzie.
  Zakaz subsurface scattering, displacement i high-poly.
- **Tekstury:** affine warping delikatny (shader), filtrowanie bilinear,
  brak ostrych mipmap zjazdów. Powtarzalne wzory bez widocznego szwu.
- **Efekty:** mgła liniowa, ziarno filmowe 3–6%, vignette subtelna, lekki
  vertex snap/wobble. Brak motion blur, DOF i fizycznego szkła.
- **Czytelność:** każdy asset testowany w 256 px. Jeśli po zmniejszeniu nie
  wiadomo, co to jest — do poprawy.
- **Interfejs:** UI rysuje silnik. W grafice zero liter, cyfr, strzałek, ramek.

## 6. Kompozycja

- Tła 4:3-safe: ważna treść w centralnych 80%; margines 10% może zostać
  przycięty przez UI lub letterbox.
- Horyzont: dzień 55–60% wysokości, zmierzch 45–50%, noc 40% (więcej nieba).
- Punkt zainteresowania poza środkiem (trójpodział). Środek zostawiamy na
  postać gracza lub wydarzenie.
- Portrety: popiersie, oczy na górnej linii trójpodziału, tło ciemne i płaskie,
  sylwetka oddzielona od tła wartością, nie kolorem.
- Wróg: czytelna, nieludzka sylwetka; twarz nieczytelna, bez konkretnych cech.

## 7. Lista assetów v1

### Tła (5)

| ID | Opis | Źródło | Runtime |
|---|---|---|---|
| `bg_village_day` | wieś za dnia, droga, chałupy, mgła | 768×576 | 640×480 |
| `bg_village_dusk` | ta sama wieś, zmierzch, zapalone okna | 768×576 | 640×480 |
| `bg_village_night` | ta sama wieś, noc, księżyc, latarka | 768×576 | 640×480 |
| `bg_cottage_interior` | wnętrze chałupy, piec, stół, świeca | 768×576 | 640×480 |
| `bg_forest_lake` | korytarz leśny i jezioro, mgła | 768×576 | 640×480 |

### Portrety (6)

| ID | Opis | Źródło | Runtime |
|---|---|---|---|
| `portrait_hero` | bohater, 30–40 lat, zmęczony, kurtka | 512×512 | 512 / 256 |
| `portrait_npc_elder` | starsza kobieta, chusta, surowe rysy | 512×512 | 512 / 256 |
| `portrait_npc_priest` | ksiądz, czarny płaszcz, zmęczone oczy | 512×512 | 512 / 256 |
| `portrait_npc_neighbor` | sąsiad, wiatrówka, nieufny | 512×512 | 512 / 256 |
| `portrait_npc_child` | dziecko, 10 lat, ubranie z lat 90. | 512×512 | 512 / 256 |
| `portrait_enemy_silhouette` | sylwetka wroga, wysoka, chuda, bez twarzy | 512×512 | 512 / 256 |

### Tekstury i propsy (v1, następne partie)

- Ściany: `tex_wood_plank`, `tex_plaster`, `tex_stone`.
- Dachy: `tex_roof_tar`, `tex_thatch`.
- Grunt: `tex_ground_mud`, `tex_forest_floor`, `tex_gravel`.
- Woda: `tex_water_lake` (animowana).
- Propsy: płot, studnia, kapliczka, latarnia, drzwi, okno, piec, stół, krzesło,
  narzędzia (kosa, siekiera, wiadro), opona, plakat wyborczy bez tekstu.
- Bronie: pistolet, strzelba (model + tekstura).
- UI: ikony amunicji, zdrowia, ekwipunku (rysowane w silniku, nie w AI).

## 8. Wymiary i format

| Klasa | Źródło AI | Finalne | Format |
|---|---|---|---|
| Tło | 768×576 | 640×480 | PNG bez alfa |
| Portret | 512×512 | 512×512, LOD 256 | PNG, opcjonalnie alfa |
| Tekstura | 512×512 | 256×256 lub 128×128 | PNG, tiling |
| Ikona UI | — | 64×64 / 32×32 | PNG z alfa |
| Woda | 512×512 | 128×128 | PNG, animacja 8 klatek |

## 9. Zakazy

- Tekst, litery, cyfry, napisy, plakaty z treścią, znaki drogowe z tekstem.
- NSFW, nagość, gore eksponowane, wizerunki realnych osób.
- Logotypy, marki, znaki towarowe, cudze postacie i modele.
- Współczesne przedmioty po 1999: smartfony, nowoczesne auta, LED, plastik.
- Fotorealizm, HDR, bloom, lens flare, chromatic aberration, ray tracing.
- Nasycone kolory, neon, czysta czerń i biel, tęcza.
- Fantasy: rogi, skrzydła, ogień z oczu, zmyślone imiona demonów.
- Modele niekomercyjne (Flux dev) i checkpointy NSFW.
- Asset bez wpisu w `art/manifest.json`.

## 10. Pipeline i akceptacja

1. Prompt po angielsku, styl opisany rzeczownikami, powtarzaj seed przy iteracji.
2. Generacja wyłącznie `python3 tools/gen.py` (checkpoint `sd_xl_base_1.0.safetensors`,
   licencja OpenRAIL++-M).
3. Ocena: kompozycja, spójność z paletą, czytelność w 256 px, artefakty
   (dłonie, twarze, perspektywa, powielone elementy), brak tekstu.
4. Zaakceptowane → `art/final/`, odrzucone zostają w `art/raw/`.
5. Manifest: `status: final`, `category`, `notes` z uzasadnieniem.
