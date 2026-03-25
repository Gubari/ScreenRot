# OVERFLOW: UI HELL

## Game Design Document --- FINALNA VERZIJA

### Game Jam tema: "There Is Not Enough Screen"

# PREGLED IGRE

**Žanr**: Top-down Arkadni Shooter + UI Management Hybrid\
**Perspektiva**: Top-down 2D\
**Kontrole**: Tastatura (WASD) + Miš (nišanjenje + UI interakcija)\
**Trajanje runa**: ~5-8 minuta (3 wave-a + boss fight)\
**Ciljna platforma**: PC (Windows/Linux), potencijalno Web (HTML5)

**Elevator Pitch u jednoj rečenici**:\
Top-down shooter u kojem ubijanje neprijatelja puni ekran glitch debris-om i haotičnim UI elementima, a na kraju svakog ciklusa bos KORISTI UI kao oružje protiv tebe.

# STRUKTURA JEDNOG RUNA

> ┌─────────────────────────────────────────────────────────┐\
> │ WAVE 1 (~60-90s) │\
> │ Čist shooter. Debris = vizuelni glitch. │\
> │ Uvod u mehanike. Lagani neprijatelji. │\
> │ │\
> │ → Level-up pauza (biraš 1 od 3 upgrade-a) │\
> ├─────────────────────────────────────────────────────────┤\
> │ WAVE 2 (~60-90s) │\
> │ Debris + prvi UI elementi (pop-up reklame, notifikacije│\
> │ Jači neprijatelji. Dual-task počinje. │\
> │ │\
> │ → Level-up pauza (biraš 1 od 3 upgrade-a) │\
> ├─────────────────────────────────────────────────────────┤\
> │ WAVE 3 (~60-90s) │\
> │ Puni haos. Debris + agresivni UI elementi. │\
> │ Cookie banneri, update prozori, chat box. │\
> │ Najteži wave --- priprema za bosa. │\
> │ │\
> │ → Level-up pauza (biraš 1 od 3 upgrade-a) │\
> ├─────────────────────────────────────────────────────────┤\
> │ BOSS FIGHT (~90-120s) │\
> │ Debris sistem se gasi. UI Overload na MAX. │\
> │ Boss generiše UI elemente kao napade. │\
> │ 3 faze: Business as Usual → Eskalacija → Desperation │\
> │ │\
> │ → Pobeda = krediti + skor │\
> │ → Smrt = krediti bazirani na progresu │\
> ├─────────────────────────────────────────────────────────┤\
> │ UPGRADE SHOP (između runova) │\
> │ Troši kredite na permanentne upgrade-ove. │\
> │ Otključaj nove oružja, karaktere, sposobnosti. │\
> │ │\
> │ → Novi run (težina raste sa svakim pobedjenim bosom) │\
> └─────────────────────────────────────────────────────────┘

# CORE MEHANIKE

## 1. Kretanje i pucanje

-   **WASD**: Kretanje u 8 smerova

-   **Miš (levi klik / auto-fire)**: Puca u pravcu kursora

-   Automatsko pucanje dok držiš levi klik (fire rate zavisi od oružja)

-   Arena je fiksne veličine --- nema scrollinga, ekran = celo polje borbe

-   Igrač ima 5 HP (prikazano kao srca u ćošku)

## 2. Debris sistem (Wave mehanika)

Svaki ubijeni neprijatelj ostavlja vizuelni debris NA EKRANU (ne na podu arene, već na samom ekranu kao overlay).

### Tipovi debrisa:

-   **Dead Pixels**: Crni ili beli kvadratići (3x3 do 8x8 px)

-   **Static Noise**: Pravougaonik TV šuma

-   **Glitch Lines**: Horizontalne trake poremećenih boja

-   **Corruption Blocks**: Veći blokovi iskrivrljene slike

### Debris akumulacija:

-   Wave 1: Neprijatelji ostavljaju SAMO vizuelni debris (glitch artefakte)

-   Wave 2: Neki debris se "transformiše" u UI elemente posle 3-5 sekundi

-   Wave 3: Neprijatelji direktno spawn-uju UI elemente umesto debrisa

### Debris merenje:

-   Ekran ima procenat "pokrivenosti" (0-100%)

-   Prikazan diskretno kao mali bar u ćošku

-   0-25% = CLEAN (zeleno)

-   25-50% = MESSY (žuto)

-   50-75% = CHAOTIC (narandžasto)

-   75-100% = CRITICAL (crveno, ekran treperi)

## 3. Defrag / Screen Clear

-   **SPACE**: Aktivira "Defrag" --- čisti SAV debris i UI elemente odjednom

-   Cooldown: 12 sekundi (može se smanjiti upgrade-om)

-   Tokom Defrag-a (0.5s): Igrač je nepomičan, ekran ima satisfying "čišćenje" animaciju

-   **Shift + Klik na UI element**: Manuelno zatvori jedan UI prozor (bez cooldown-a, ali zahteva preciznost mišem)

## 4. Skor Multiplikator

Risk-reward sistem koji nagrađuje igranje sa mnogo debrisa na ekranu:

  --------------------------------------------------------------------------------
  **Pokrivenost ekrana**   **Multiplikator**   **Efekat**
  ------------------------ ------------------- -----------------------------------
  0-25%                    x1                  Čisto, lako se igra

  25-50%                   x2                  Počinje da smeta

  50-75%                   x3                  Teško se vidi

  75%+                     x5                  Skoro nemoguće, ali MASIVNI poeni
  --------------------------------------------------------------------------------

-   Multiplikator se primenjuje na SVE poene (ubijanje, boss damage, pickup-ove)

-   Defrag RESETUJE multiplikator na x1

-   Smrt na visokom multiplikatoru: Gubiš bonus poene iz trenutnog wave-a

## 5. UI elementi (Dual-layer gameplay)

Počevši od Wave 2, pojavljuju se UI elementi koji zaklanjaju ekran. Oni su overlay PREKO gameplay-a --- ispod njih se i dalje dešava akcija, ali je ne vidiš.

### UI katalog:

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Element**                  **Kad se pojavljuje**   **Veličina**             **Kako ga neutrališeš**                                        **Vreme pre auto-nestanka**
  ---------------------------- ----------------------- ------------------------ -------------------------------------------------------------- -----------------------------
  **Pop-up Ad**                Wave 2+                 Srednji (150x100px)      Klikni mali "X" u ćošku                                      8s

  **Cookie Banner**            Wave 2+                 Širok (ceo donji deo)    Klikni "Accept All"                                          Ne nestaje sam!

  **Notification Bell**        Wave 2+                 Mali (50x50px)           Klikni na njega                                                5s (ali trepće ekran)

  **Software Update**          Wave 3+                 Srednji                  Klikni "Later" u roku od 4s, inače 2s FREEZE                 4s (pa freeze)

  **Chat Box**                 Wave 3+                 Srednji-Velik            Klikni "Mute" ili prevuci van ekrana                         Ne nestaje sam!

  **CAPTCHA**                  Samo Boss Fight         Velik                    Reši mini-puzzle (klikni 3 tačne slike)                        Ne nestaje dok ne rešiš

  **Terms & Conditions**       Samo Boss Fight         OGROMAN (80% ekrana)     Skroluj do dna, klikni "I Agree"                             Ne nestaje sam!

  **"Free iPhone" Banner**   Wave 3+                 Srednji, BLINKA          NE KLIKAJ --- nestaje sam posle 5s. Ako klikneš = gubiš 1 HP   5s

  **Error Dialog**             Samo Boss Fight         Mali                     Klikni "OK"                                                  6s

  **Toolbar/Ribbon**           Samo Boss Fight         Širok (ceo gornji deo)   Klikni "Minimize"                                            Ne nestaje sam!
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**PRAVILO**: UI elementi se broje u debris procenat. Cookie Banner koji zauzima 15% ekrana = +15% debris.

# WAVE DIZAJN

## Wave 1: "Boot Up" (~60-90 sekundi)

**Atmosfera**: Čisto, mirno, uči se igra.

**Neprijatelji**:

  ------------------------------------------------------------------------------------------------------------------------
  **Tip**             **Sprite**               **Ponašanje**                           **HP**   **Debris**
  ------------------- ------------------------ --------------------------------------- -------- --------------------------
  **Pixel Grunt**     Mali zeleni kvadrat      Ide pravo ka igraču, sporo              1        Mali dead pixel (3x3)

  **Static Walker**   Sivi krug sa šumom       Zig-zag kretanje, srednje brz           2        Static noise patch (5x5)

  **Bit Bug**         Mali insekt od piksela   Brz ali slab, dolazi u grupama po 3-5   1        Minimalan (2x2)
  ------------------------------------------------------------------------------------------------------------------------

**Spawn pattern**:

-   0-15s: 3 Pixel Grunta, jedan po jedan

-   15-30s: 2 Static Walkera + 3 Bit Bug-a

-   30-45s: Mešavina, ubrzano

-   45-60s: Mini-horda (8-10 Gruntova odjednom)

-   60-75s: Finalni talas --- 2 Static Walkera + 5 Bit Bugova + 4 Grunta

-   Wave kraj: Svi ubijeni = level-up pauza

**Debris stanje na kraju Wave 1**: ~15-25% ekrana pokriveno

## Wave 2: "Pop-Up Storm" (~60-90 sekundi)

**Atmosfera**: Debris raste, UI počinje da iskače. Igrač oseća prvi put "nemam dovoljno ekrana".

**Novi neprijatelji**:

  ----------------------------------------------------------------------------------------------------------------------------------------------------
  **Tip**             **Sprite**        **Ponašanje**                                                    **HP**   **Debris**
  ------------------- ----------------- ---------------------------------------------------------------- -------- ------------------------------------
  **Glitch Dasher**   Crvena strelica   Sprint u pravoj liniji, brz                                      2        Glitch linija (horizontalna traka)

  **Ad Drone**        Leteći banner     Ne napada direktno --- kad umre, spawn-uje Pop-up Ad na ekranu   3        Pop-up Ad UI element
  ----------------------------------------------------------------------------------------------------------------------------------------------------

**Spawn pattern**:

-   0-20s: Gruntovi + Dasheri, debris se gradi

-   20-40s: Prve Ad Drone pojave --- kad ih ubiješ, iskače Pop-up!

-   40-60s: Cookie Banner se pojavljuje (mora se ručno zatvoriti)

-   60-80s: Intenzivni miks --- Dasheri jure, Ad Droneovi spamuju, Notification Bellovi pucketaju

-   Wave kraj: Automatski Defrag (čisti ekran pre bossa bi bio premalo, ali daje predah)

**UI elementi aktivni**: Pop-up Ad, Cookie Banner, Notification Bell\
**Debris stanje na kraju Wave 2**: ~30-50% (zavisi od toga koliko je igrač čistio)

## Wave 3: "System Overload" (~60-90 sekundi)

**Atmosfera**: Potpuni haos. Ekran je preplavljen. Muzika je distortovana. Igrač jedva vidi.

**Novi neprijatelji**:

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Tip**                    **Sprite**               **Ponašanje**                                                       **HP**   **Debris**
  -------------------------- ------------------------ ------------------------------------------------------------------- -------- ------------------------------------------------------
  **Corruption Spawner**     Veliki ljubičasti blok   Stoji na mestu, šalje manje neprijatelje                            5        Veliki corruption block (10x10)

  **Screen Eater**           Crni krug koji raste     Polako se kreće, ali DOK JE ŽIV debris raste sam                    4        Ne ostavlja debris kad umre, ALI generiše dok je živ

  **Firewall** (Mini-boss)   Narandžasti štit         Pojavljuje se jednom --- jak, ali kad ga ubiješ čisti 30% debrisa   8        Čisti debris kad umre!
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Spawn pattern**:

-   0-15s: Svi tipovi neprijatelja iz Wave 1 i 2, ubrzano

-   15-30s: Corruption Spawner se pojavljuje --- prioritetni target!

-   30-45s: Screen Eater dolazi --- debris aktivno raste dok ga ne ubiješ

-   30-45s: Software Update iskače (mora se kliknuti "Later" ili freeze!)

-   45-60s: Chat Box se pojavljuje + "Free iPhone" bait banner

-   60-75s: FIREWALL mini-boss --- ubij ga za veliko čišćenje debrisa

-   75-90s: Finalna horda --- sve odjednom, posle čega wave završava

**UI elementi aktivni**: Svi iz Wave 2 + Software Update, Chat Box, "Free iPhone" bait\
**Debris stanje na kraju Wave 3**: Varijabilno (30-70% zavisno od skilll-a)

## Pre-Boss Transition

-   Svi preostali neprijatelji i debris se AUTOMATSKI čiste (satisfying Defrag animacija celog ekrana)

-   2 sekunde mira --- crn ekran, samo tihi hum

-   Boss health bar se pojavljuje NA VRHU ekrana

-   Boss ulazi sa dramatičnom animacijom

-   Muzika se menja u boss temu

# BOSS FIGHTS

## Sistem bossova

Igra ima **4 bossa**. Na početku, igrač se bori samo protiv Boss 1. Kad ga pobedi, sledeći run ima iste wave-ove ali Boss 2 na kraju. Itd.

Posle sva 4 bossa: otključava se **Endless Mode** (beskonačni wave-ovi + random boss na svakih 3 wave-a).

## BOSS 1: "THE BLOATWARE"

**Izgled**: Ogromni instalacioni wizard prozor sa nasmejanim maskotom (clipart stil). Zauzima ~20% ekrana kao entity koji se kreće.

**HP**: 100\
**Kretanje**: Polako pluta po areni, bounce-uje od zidova

### Faza 1 --- "Installation Wizard" (100-60% HP)

**Napadi**:

-   **"Next >" Projektili**: Ispucava dugmad sa tekstom "Next >" koja lete ka igraču. Lako se izbegavaju, lete u pravoj liniji. Svaka 2 sekunde.

-   **"Install" Bomba**: Na svaka 8 sekundi, baci AoE krug na poziciju igrača. Eksplodira posle 1.5s --- lako se izbegne ako pratiš.

-   **Toolbar Drop**: Na svakih 15s, spawn-uje Toolbar/Ribbon na vrhu ekrana (mora se minimizirati kliком).

**UI Spam**: Pop-up reklame se pojavljuju svakih 10s (1 po 1, lagano).

### Faza 2 --- "Bundle Software" (60-30% HP)

**Novi napadi**:

-   **"Accept Terms" Blokada**: Baca Terms & Conditions prozor na random poziciju --- blokira 30% ekrana. Mora se skrolovati i kliknuti "I Agree" da se ukloni. Pojavljuje se 2 puta u fazi.

-   **"Bundled App" Summon**: Na svakih 12s, spawn-uje malog neprijatelja (Pixel Grunt) iz Pop-up prozora.

-   Fire rate "Next >" projektila raste (svaka 1.5s)

**UI Spam**: Pop-up reklame svakih 7s, Cookie Banner se pojavljuje jednom.

### Faza 3 --- "Desperate Uninstall" (30-0% HP)

**Ponašanje**: Boss se ubrzava, počinje da "paničari"\
**Novi napadi**:

-   **"Are You Sure?" Dialog Chain**: Brzo šalje Error Dialog-e ("Uninstall failed!" / "Retry?") --- svaki mora da se klikne "OK", a dok ga ne klikneš, ne možeš da pucaš!

-   **"Restart Required"**: Jednom u fazi --- ceo ekran postaje Software Update, igrač ima 3s da klikne "Later" ili se igra PAUZIRA na 3s

-   Ubrzani projektili, brže kretanje

**Smrt bossa**: Explodiraj u hiljade piksela, ekran se "defragmentira" sa zadovoljavajućom animacijom. "Successfully Uninstalled" poruka.

## BOSS 2: "THE SOCIAL FEED"

**Izgled**: Gigantski smartphone ekran sa infinite scroll feed-om. Svetli, šaren, agresivno veseo.

**HP**: 130\
**Kretanje**: Pluta brže nego Bloatware, menja pravac nepredvidivo

### Faza 1 --- "Your Feed" (100-60% HP)

**Napadi**:

-   **"Like" Projektili**: Srce-oblici koji lete ka igraču, 3 u lepezi. Svake 2s.

-   **"Share" Boomerang**: Baca "Share" dugme koje se vraća nazad (mora se izbegavati dva puta).

-   **"Notification Storm"**: Na svakih 10s, 3 Notification Bell-a iskočе istovremeno (trepću ekran).

**UI Spam**: Chat Box se pojavljuje i "puni" se porukama (mora se mute-ovati).

### Faza 2 --- "Algorithm Takeover" (60-30% HP)

**Novi napadi**:

-   **"Recommended For You"**: Spawn-uje "preporučene sadržaje" (slike) koje zaklanjaju ekran --- nisu klikabilne, nestaju posle 4s, ali dolaze u talasima.

-   **"Doom Scroll"**: Ceo ekran počinje da se "skroluje" vertikalno --- gameplay prostor se pomera na dole 3 sekunde (disorienting!)

-   **"Swipe" Napad**: Boss pravi horizontalni "swipe" --- linija projektila koja pokriva celu širinu ekrana, samo mali gap za prolaz.

**UI Spam**: Notification Bell-ovi + Cookie Banner + "Free iPhone" bait banner

### Faza 3 --- "Going Viral" (30-0% HP)

-   **"Trending" Horda**: Spawn-uje 10 malih neprijatelja odjednom ("viral content")

-   Sve prethodne napade koristi brže i u kombinacijama

-   **"Screen Time Limit"**: Jednom --- ekran počinje da se gasi (fadeout ka crnom), igrač ima 5s da napravi dovoljno damage-a pre nego ekran potpuno potamni. Ako ne ubije bosa, ekran se vraća ali boss regeneriše 10% HP.

**Smrt bossa**: Eksplozija emoji-ja i srca, "Account Deleted" poruka.

## BOSS 3: "THE LEGACY SYSTEM"

**Izgled**: Stari CRT monitor sa Windows 95 interfejsom. Spor, masivan, zastrašujući.

**HP**: 160\
**Kretanje**: VEOMA spor, ali zauzima veliki deo ekrana fizički

### Faza 1 --- "Boot Sequence" (100-60% HP)

**Napadi**:

-   **"Not Responding" Freeze**: Na svakih 12s, igra se "zamrzne" na 1.5s --- ali boss nastavlja da se kreće (samo igrač je frozen). Praćeno Windows "Not Responding" porukom na title bar-u.

-   **"Blue Screen Zones"**: Postepeno pretvara delove arene u BSOD (plavi ekran) --- ako stojiš na BSOD zoni, gubiš HP.

-   **"Error 404" Projektili**: Spori, ali VELIKI projektili (error dialog kutije) koji zauzimaju mnogo prostora.

**UI Spam**: Error Dialogs ("An error has occurred" sa "OK" dugmetom) svakih 8s.

### Faza 2 --- "Memory Leak" (60-30% HP)

**Novi napadi**:

-   **"RAM Overflow"**: Delovi ekrana postaju CRNI (kao da se gase) --- počinje sa ćoškovima i širi se ka centru. Crni delovi se vraćaju posle 5s ali dolaze u talasima.

-   **"Virus Scan"**: Pojavljuje se "antivirus" prozor koji SKENIIRA ekran horizontalnom linijom. Kad linija pređe igrača = 1 damage. Mora se skočiti (dash) da se izbegne.

-   **"Disk Full" Zone**: Deo arene postaje "full" --- igrač se USPORAVA za 50% dok je u toj zoni.

**UI Spam**: Error Dialogs + Software Update + Toolbar

### Faza 3 --- "System Failure" (30-0% HP)

-   **"Total Crash"**: Ekran se POTPUNO GASI na 2s (crno), pa se vrati --- ali pozicije neprijatelja (i bossa) su promenjene

-   Svi prethodni napadi ubrzani i kombinovani

-   **"Format C:\\"**: Jednom u fazi --- progresivni brisač koji briše ekran od leva ka desno. Moraš naneti dovoljno damage-a pre nego "obriše" igrača.

**Smrt bossa**: CRT shutdown animacija (slika se smanjuje u tačku), "System shut down successfully."

## BOSS 4 (FINAL): "THE INTERNET"

**Izgled**: Amorfna masa svega --- delovi svih prethodnih bosova + browseri, linkovi, meme-ovi, pop-upi. Stalno menja oblik.

**HP**: 200\
**Kretanje**: Teleportuje se na random poziciju svakih 6s

### Faza 1 --- "World Wide Web" (100-70% HP)

-   Koristi napade SVIH prethodnih bosova, random rotacija

-   UI spam iz svih prethodnih bosova istovremeno (ali umereno)

### Faza 2 --- "Deep Web" (70-40% HP)

-   Ekran postaje TAMAN (kao dark mode) --- jedino što svetli su boss, igrač, i UI elementi

-   **"Phishing Attack"**: Lažni Power-up se pojavi --- ako ga pokupriš, gubiš 2 HP

-   **"DDoS"**: Ogromna horda Pixel Gruntova (20+) se spawn-uje odjednom

-   **"Firewall Block"**: Zidovi se privremeno pojavljuju u areni, blokiraju pucanje

### Faza 3 --- "404: Reality Not Found" (40-0% HP)

-   **SVE ODJEDNOM** --- svi tipovi UI-ja, svi tipovi napada

-   CAPTCHA se pojavljuje --- dok je rešavaš, ne možeš da pucaš ili se krećeš

-   Ekran je 80-90% prekriven --- igrač vidi skoro NIŠTA

-   Na 10% HP: Boss baca finalni "Terms & Conditions" --- ogroman, zauzima 90% ekrana. Igrač mora da skroluje do dna i klikne "I Agree" da bi mogao da zada finalni udarac. Dok skroluje, boss šalje projektile.

-   **Finalni udarac**: Kad boss padne na 0 HP, igrač mora kliknuti "UNSUBSCRIBE" dugme koje se pojavi na centru ekrana.

**Smrt bossa**: Sve eksplodira. Ekran se čisti do savršene beline. Poruka: "Connection terminated. You are free." Tihi zvuk. Credits.

# UPGRADE SISTEMI

## A) In-Run Upgrade-ovi (biraju se tokom runa)

Posle svakog wave-a, pojavljuje se ekran sa 3 random upgrade-a. Biraš 1.

### Ofanzivni:

  -------------------------------------------------------------------------------------------------------
  **Upgrade**            **Efekat**                                       **Ikona**
  ---------------------- ------------------------------------------------ -------------------------------
  **Fire Rate+**         Pucanje 20% brže                                 Metak sa strelicama

  **Spread Shot**        Pucaš 3 metka u lepezi (manje damage po metku)   3 linije u lepezu

  **Piercing Rounds**    Meci prolaze kroz 2 neprijatelja                 Metak sa strelicom kroz njega

  **Ricochet**           Meci se odbijaju od ivica ekrana jednom          Strelica sa bounce-om

  **Explosive Rounds**   Meci eksplodiraju na kontakt (mali AoE)          Metak sa eksplozijom

  **Overcharge**         Na x3+ multiplikatoru, +50% damage               Munja
  -------------------------------------------------------------------------------------------------------

### Defanzivni:

  ----------------------------------------------------------------------------------------------------
  **Upgrade**       **Efekat**                                           **Ikona**
  ----------------- ---------------------------------------------------- -----------------------------
  **Shield**        Jednom po wave-u, apsorbuje 1 hit                    Štit

  **Speed Boost**   +15% brzina kretanja                                 Čizma

  **HP Regen**      Regeneriše 1 HP na početku svakog wave-a             Srce sa strelicom

  **Dash**          SPACE dvaput brzo = dash (brzi pomak, 3s cooldown)   Strelica sa speedline-ovima
  ----------------------------------------------------------------------------------------------------

### UI Management:

  ------------------------------------------------------------------------------------------
  **Upgrade**           **Efekat**                                         **Ikona**
  --------------------- -------------------------------------------------- -----------------
  **Ad Block**          Automatski zatvara 1 Pop-up reklamu svakih 8s      Štit sa "X"

  **Dark Mode**         Debris postaje poluprovidni na 3s (cooldown 15s)   Mesec

  **Defrag+**           Defrag cooldown smanjujen za 3s                    HDD ikona

  **Auto-Close**        UI elementi se automatski zatvaraju 2s brže        Sat

  **Spam Filter**       Cookie Banneri se pojavljuju 50% ređe              Filter ikona

  **Premium Account**   Svi UI elementi su 30% manji                       Zlatna zvezda
  ------------------------------------------------------------------------------------------

## B) Meta-Progression (između runova)

### Valuta: "Data Credits"

-   Zarađuješ ih na kraju svakog runa

-   Formula: (Bazni krediti za wave dostignut) + (Boss HP % skinute × 10) + (Skor ÷ 1000)

-   Wave 1 smrt = ~10 kredita, Wave 3 smrt = ~40 kredita, Boss pobeda = ~100 kredita

### Permanentni upgrade-ovi (kupuju se u shopu):

**Tier 1 (jeftini, 20-50 kredita):**

  -------------------------------------------------------------------------------
  **Upgrade**              **Cena**   **Efekat**
  ------------------------ ---------- -------------------------------------------
  HP+1                     30         Počni sa 6 umesto 5 HP

  Quick Boot               20         Wave 1 počinje sa 10% manje neprijatelja

  Defrag Cooldown -1s      40         Početni Defrag cooldown je 11s umesto 12s

  Starting Speed +5%       25         Malo brže kretanje od starta
  -------------------------------------------------------------------------------

**Tier 2 (srednji, 60-120 kredita):**

  -------------------------------------------------------------------------------------
  **Upgrade**             **Cena**   **Efekat**
  ----------------------- ---------- --------------------------------------------------
  HP+2                    80         Počni sa 7 HP

  Firewall Friend         100        Firewall mini-boss se pojavljuje i u Wave 2

  Ad Blocker Lite         60         Počni svaki run sa jednim besplatnim Ad Block-om

  Defrag Cooldown -2s     90         Defrag na 10s

  Lucky Rolls             100        Level-up nudi 4 izbora umesto 3
  -------------------------------------------------------------------------------------

**Tier 3 (skupi, 150-300 kredita):**

  ---------------------------------------------------------------------------------------------
  **Upgrade**         **Cena**   **Efekat**
  ------------------- ---------- --------------------------------------------------------------
  HP+3                200        Počni sa 8 HP

  VPN Shield          150        Jednom po boss fight-u, ignoriše jednu UI "napad" mehaniku

  Overclock           250        Počni svaki run sa random upgrade-om već izabranim

  Double Credits      300        Zarađuješ 2x kredite (kupuješ jednom, traje zauvek)
  ---------------------------------------------------------------------------------------------

### Otključavanje oružja:

  -------------------------------------------------------------------------------------------------------------
  **Oružje**                   **Cena**     **Opis**
  ---------------------------- ------------ -------------------------------------------------------------------
  **Pixel Pistol** (default)   Besplatno    Balansirani, jedan metak, srednji damage

  **Scatter Gun**              80           Shotgun stil --- 5 metaka u lepezi, kratak domet

  **Laser Pointer**            120          Kontinuirani laser, visok DPS ali moraš biti precizan

  **Orbit Cannon**             200          2 orbiting metka kruže oko igrača automatski + normalno pucanje

  **Glitch Gun**               250          Meci BRIŠU debris kroz koji prođu (manje damage, ali čisti ekran)
  -------------------------------------------------------------------------------------------------------------

Igrač bira oružje PRE runa.

### Otključavanje karaktera:

  ----------------------------------------------------------------------------------------------------------
  **Karakter**           **Cena**      **Pasivna sposobnost**
  ---------------------- ------------- ---------------------------------------------------------------------
  **Cursor** (default)   Besplatno     Balansirani statovi

  **Proxy**              100           20% brže kretanje, -1 HP

  **Firewall**           150           +2 HP, Defrag čisti 15% više, ali 10% sporije kretanje

  **Root**               200           Debris mu smeta 30% manje (poluprovidni), ali nema Dash

  **Incognito**          300           UI elementi se pojavljuju 25% ređe, ali multiplikator raste sporije
  ----------------------------------------------------------------------------------------------------------

# ENDLESS MODE

Otključava se posle pobede nad Boss 4.

**Struktura**:

-   Beskonačni ciklusi: 3 wave-a + random boss

-   Svaki ciklus je teži: neprijatelji imaju više HP, brži su, UI je agresivniji

-   Boss rotacija je random (može se ponoviti)

-   Na svakih 5 ciklusa: "MEGA WAVE" --- poseban wave gde se SVE dešava istovremeno (svi tipovi neprijatelja + svi UI elementi + debris)

-   High score leaderboard (lokalni + potencijalno online)

**Zašto je adiktivan**:

-   "Koliko daleko mogu da stignem?" mentalitet

-   Svaki ciklus je dovoljno kratak da "još jedan" deluje razumno

-   Boss rotacija znači da se nikad ne zna šta dolazi

-   Skor multiplikator nagrađuje rizik --- igrači se takmiče za veće brojeve

# VIZUALNI STIL

## Opšta estetika

**Gameplay prostor**: Čist, neon-na-crnom, minimalistički (inspirisan Geometry Wars, Vampire Survivors)

-   Crna pozadina sa suptilnom grid mrežom

-   Igrač je svetli neon oblik (zavisno od karaktera)

-   Neprijatelji su jarki, jasno čitljivi oblici

-   Meci su beli/žuti svetleći tragovi

**Debris sloj**: Retro CRT/VHS glitch estetika

-   Dead pikseli, scanlines, RGB split, TV šum

-   Kontrast sa čistim gameplay-om je DRASTIČAN i tematski

**UI elementi**: Hiperrealističan imitacija pravih UI elemenata

-   Pop-up reklame izgledaju kao prave (ali sa smešnim tekstom: "Hot Singles In Your Arena!")

-   Windows XP/7 stil error dijalozi

-   Cookie banneri identični pravim

-   CAPTCHA izgleda kao prava Google reCAPTCHA

-   Chat Box imitira Twitch chat (sa smešnim porukama: "git gud lol", "dodge pls")

**Kontrast stilova**: Igra u centru je NEON PIXEL-ART, a UI oko nje je REALISTIČNI 2000s INTERNET --- sudar stilova je vizualno upečatljiv i komičan.

## Ekranski efekti

-   CRT zakrivljenost na ivicama (suptilna)

-   Scanlines overlay (lagani, ne ometaju gameplay)

-   Kad debris je 50%+: Ekran počinje da treperi

-   Kad debris je 75%+: RGB split efekat, ekran se "lomi"

-   Boss fight: Dramatično osvetljenje, screen shake na pogocima

-   Defrag animacija: Pikseli se "slažu" od gore ka dole, kao prava defragmentacija diska

-   Smrt: BSOD ekran sa "Game Over" porukom u Windows error formatu

## UI dizajn (pravi game UI, ne overlay neprijatelji)

-   HP: 5 pikselihanih srca, gornji levi ugao

-   Skor: Gornji desni ugao, sa aktivnim multiplikatorom

-   Defrag cooldown: Mali bar ispod HP-a

-   Debris %: Diskretni bar ispod skora

-   SVE je minimalno --- da se razlikuje od haotičnog UI overlay-a

# AUDIO DIZAJN

## Muzika

### Wave muzika: Adaptivni Synthwave/Chiptune

Jedna track koja se MENJA dinamički bazirano na debris procentu:

  ------------------------------------------------------------------------------------------------
  **Debris %**           **Muzički sloj**
  ---------------------- -------------------------------------------------------------------------
  0-25%                  Čist synth beat, melodičan, ritmičan

  25-50%                 Dodaje se bit-crush na melodiju, bass postaje teži

  50-75%                 Melodija je distortovana, dodate su glitch perkusije

  75%+                   Muzika je skoro potpuno corrupted --- kakofonija, ali i dalje ima ritam

  Defrag aktiviran       0.5s tišina, pa čist synth se vraća
  ------------------------------------------------------------------------------------------------

### Boss muzika:

-   **Bloatware**: Iritantno vesela midi melodija (kao instalacioni wizard iz 2003) koja postaje sve agresivnija

-   **Social Feed**: Pop/EDM parodija sa notification zvukovima kao instrumenati

-   **Legacy System**: Spora, ominozna, sa Windows zvukovima (startup, error, shutdown) kao ritmičkim elementima

-   **The Internet**: Kolaž svih prethodnih boss tema koji se raspada i sastavlja

## Zvučni efekti

  ---------------------------------------------------------------------------------------------
  **Događaj**                    **Zvuk**
  ------------------------------ --------------------------------------------------------------
  Pucanje                        Čist "pew" (chiptune)

  Pogodak neprijatelja           Kratki "hit" crunch

  Ubijanje neprijatelja          Glitch zvuk (kratki burst statičkog šuma)

  Debris nastaje                 Tihi "crackle" (kao TV šum)

  Pop-up iskače                  Windows "ding!" notifikacija

  Pop-up zatvoren                Satisfying "whoosh" + "click"

  Cookie Banner                  Iritantni "whoooosh" od dole

  Software Update                Frustrirajući loading zvuk

  CAPTCHA pojava                 "Bzzzt" alarm

  Error Dialog                   Windows error zvuk

  Defrag aktiviran               HDD defrag zvuk (mehaničko klikanje pa "woooosh" čišćenja)

  Level-up                       Retro RPG "level up" fanfara

  Boss ulazak                    Dramatični sting + screen shake zvuk

  Boss smrt                      Ogromna eksplozija + specifičan zvuk za svakog bosa

  Igrač damage                   Kratki "ugh" + screen shake

  Game Over                      Windows shutdown zvuk + BSOD "buzz"

  "Free iPhone" klik (trap!)   Trolujući "you fell for it" zvuk
  ---------------------------------------------------------------------------------------------

# HUMOR I TEKST

Humor je KLJUČAN za pamtljivost. Evo primera teksta u igri:

### Pop-up reklame (random):

-   "Hot Singles In Your Arena! Click Here!"

-   "You Are The 1,000,000th Visitor! Claim Your Prize!"

-   "DOCTORS HATE HIM! This Cursor Destroyed 99 Enemies With One Weird Trick!"

-   "Download More RAM --- FREE! [INSTALL NOW]"

-   "Your PC May Be At Risk! (It is. You\'re playing this game.)"

### Chat Box poruke (Twitch chat parodija):

-   "omg dodge the ads lol"

-   "skill issue"

-   "POGGERS nice combo"

-   "wait is this a game or my desktop??"

-   "uninstall ur browser bro"

-   "F" (kad igrač primi damage)

-   "GGEZ" (kad boss umre)

### Error Dialog poruke:

-   "An error has occurred. Actually, several. [OK]"

-   "Task \'Not Dying\' has stopped responding. [OK]"

-   "Your screen is 98% full. Would you like to buy more screen? [OK]"

### Boss death poruke:

-   Bloatware: "Successfully Uninstalled (finally)."

-   Social Feed: "Account Deactivated. Touch grass."

-   Legacy System: "System shut down. Time of death: now."

-   The Internet: "Connection terminated. You are free."

# IMPLEMENTACIJA --- PLAN RAZVOJA

## Tehnički stek

-   **Preporučeni engine**: Godot 4 (besplatan, lagan, odličan 2D)

-   **Alternativa**: Unity 2D ili čak Phaser.js (za web verziju)

-   **Debris sistem**: Render texture overlay --- crtaš debris na zasebnu teksturu koja se prikazuje preko gameplay-a

-   **UI overlay**: Standardni UI sistemi engine-a, ali spawn-ovani dinamički

## Prioriteti razvoja (za 48-72h jam)

### MUST HAVE (Minimum Viable Game) --- prvih 20h:

> 1\. ✅ Kretanje + pucanje (twin-stick) --- 2h
>
> 2\. ✅ Arena sa spawn sistemom neprijatelja --- 3h
>
> 3\. ✅ 3 tipa neprijatelja (Grunt, Dasher, Spawner) --- 3h
>
> 4\. ✅ Debris overlay sistem (render texture) --- 5h
>
> 5\. ✅ Defrag mehanika --- 2h
>
> 6\. ✅ Skor + multiplikator --- 2h
>
> 7\. ✅ 1 Boss (Bloatware) sa 2 faze --- 4h
>
> 8\. ✅ 3 tipa UI elemenata (Pop-up, Cookie, Error) --- 3h

**Rezultat posle 20h**: Igriva igra sa 3 wave-a + 1 boss. Možete submitovati ovo ako ponestane vremena.

### SHOULD HAVE (Puni doživljaj) --- sledećih 15h:

> 9\. ⬜ In-run upgrade sistem (6-8 upgrade-a) --- 4h
>
> 10\. ⬜ Još 3 UI elementa (Update, Chat, CAPTCHA) --- 3h
>
> 11\. ⬜ Boss Faza 3 + boss death animacija --- 3h
>
> 12\. ⬜ Meta-progression shop (3-4 permanentna upgrade-a) --- 3h
>
> 13\. ⬜ Vizualni polish (CRT efekti, particles, screen shake) --- 3h

### NICE TO HAVE (Za vrhunsku ocenu) --- preostalo vreme:

> 14\. ⬜ Adaptivna muzika (layered audio) --- 4h
>
> 15\. ⬜ Još 1-2 bossa --- 4-6h po bosu
>
> 16\. ⬜ Endless Mode --- 3h
>
> 17\. ⬜ Dodatni karakteri i oružja --- 3h
>
> 18\. ⬜ Leaderboard --- 2h
>
> 19\. ⬜ Humor tekst (pop-up poruke, chat) --- 1h
>
> 20\. ⬜ Sound design polish --- 2h

# ADIKTIVNI LOOP --- ZAŠTO SE IGRAČI VRAĆAJU

## Kratkoročno (unutar sesije):

-   **Arcade dopamin**: Ubijanje neprijatelja je instant zadovoljavajuće (particle eksplozije, zvuci, XP orbs)

-   **Risk-reward tenzija**: "Da li da očistim ekran ili da juram x5 multiplikator?"

-   **Humor**: Igrači žele da vide sledeći smešni pop-up ili chat poruku

-   **Boss patterns**: Svaki pokušaj je bolji jer učiš pattern-e

## Srednjoročno (između runova):

-   **"Još jedan run"**: Run traje 5-8 min --- dovoljno kratak da "još jedan" deluje razumno

-   **Meta-progression**: "Još 30 kredita i mogu da kupim novo oružje"

-   **Otključavanje sadržaja**: Novi boss, novi karakter, novo oružje --- uvek ima nešto sledeće

-   **High score jurenje**: "Mogu da dobijem bolji skor sa ovim upgrade-om"

## Dugoročno:

-   **Endless Mode**: Beskonačno takmičenje

-   **Character mastery**: Svaki karakter se igra drugačije

-   **Weapon mastery**: Svako oružje menja strategiju

-   **Community**: Deljenje high score-ova, diskusija o najboljim build-ovima

# FINALNA OCENA PO KRITERIJUMIMA

  -------------------------------------------------------------------------------------------------------------------------
  **Kriterijum**   **Ocena**      **Zašto**
  ---------------- -------------- -----------------------------------------------------------------------------------------
  **Overall**      ★★★★★          Kompletna igra --- jasna vizija, dubok gameplay, dugoročna vrednost

  **Enjoyment**    ★★★★★          Arcade dopamin + humor + "još jedan run" = zavisnost

  **Gameplay**     ★★★★★          Twin-stick shooter + debris management + UI management + boss patterns = 3 sloja dubine

  **Innovation**   ★★★★★          Debris koji prerasta u UI elemente + UI kao boss oružje = potpuno nova mehanika

  **Theme**        ★★★★★          Ekran se BUKVALNO puni i postaje neupotrebljiv --- savršena interpretacija

  **Visuals**      ★★★★★          Neon gameplay + glitch debris + realistični UI = vizuelni identitet koji se pamti

  **Audio**        ★★★★★          Adaptivna muzika koja se korumpira + Windows zvuci kao SFX = briljantno
  -------------------------------------------------------------------------------------------------------------------------

*Sretno na game jam-u! Napravite nešto što će sudije pamtiti. 🎮*
