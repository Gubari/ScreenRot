# SCREENROT --- Podela uloga i tajmlajn

## 4 programera | 72 sata | Godot 4 | Free asseti

---

# PODELA ULOGA

## IGRAČ 1: "CORE" --- Core Gameplay Programer

**Odgovornost**: Sve što se tiče igrača, pucanja, kretanja i arene.

**Konkretni taskovi**:

-   Kretanje igrača (WASD, 8 smerova)
-   Sistem pucanja (nišanjenje mišem, fire rate, različita oružja)
-   Collision sistem (meci → neprijatelji, neprijatelji → igrač)
-   HP sistem igrača (primanje damage-a, smrt, respawn)
-   Defrag mehanika (SPACE --- čišćenje ekrana, cooldown, animacija)
-   Dash mehanika (ako stigne)
-   Kamera i arena granice
-   Integracija sa sistemima ostalih članova

**Zašto on**: Core gameplay MORA da radi savršeno jer je sve ostalo bazirano na njemu. Ovo je najkritičniji zadatak i treba ga raditi neko ko je najiskusniji sa Godot-om.

**Asset potrebe**:

-   Igrač sprite (pixel art, top-down, 16x16 ili 32x32) --- sa Kenney.nl ili itch.io
-   Metak sprite --- može biti jednostavan beli krug/linija
-   Arena tilemap ili samo crna pozadina sa grid linijama

---

## IGRAČ 2: "ENEMIES" --- Neprijatelji, Wave sistem, Bosovi

**Odgovornost**: Sve što se tiče neprijatelja, spawn logike i boss AI-a.

**Konkretni taskovi**:

-   Bazni Enemy klasa (HP, kretanje ka igraču, smrt → signal za debris)
-   4-5 tipova neprijatelja sa različitim ponašanjem:
-   Pixel Grunt (ide pravo)
-   Static Walker (zig-zag)
-   Bit Bug (brz, u grupama)
-   Glitch Dasher (sprint u liniji)
-   Corruption Spawner (stoji, šalje manje)
-   Wave Manager:
-   3 wave-a sa raspoređenim spawn-ovima
-   Tajmer po wave-u
-   Eskalacija težine između wave-ova
-   Boss sistem:
-   Boss 1 "The Bloatware" --- 3 faze
-   Boss attack patterns (projektili, AoE, UI spawn-ovanje)
-   Boss health bar
-   Tranzicija između faza
-   Firewall mini-boss (Wave 3)

**Zašto on**: Neprijatelji i boss su SADRŽAJ igre --- bez njih nema šta da se igra. Ovo je drugi najkritičniji zadatak. Boss fight mora biti zabavan.

**Asset potrebe**:

-   Enemy sprite-ovi (4-5 različitih, pixel art) --- može i basic geometric shapes u neon bojama
-   Boss sprite (veći, detaljniji) --- ili napraviti od jednostavnih oblika
-   Projektil sprite-ovi za bosa

---

## IGRAČ 3: "SCREEN" --- Debris sistem, UI Overlay, Vizualni efekti

**Odgovornost**: Sve što se tiče ekrana --- debris, UI elementi, vizualni efekti, screen shake.

**Konkretni taskovi**:

-   Debris Overlay sistem:
-   SubViewport ili CanvasLayer koji renderuje debris PREKO gameplay-a
-   Debris generisanje na poziciji ubijenog neprijatelja
-   Različiti tipovi debrisa (dead pixels, static noise, glitch lines)
-   Debris procenat tracker (0-100%)
-   Defrag čišćenje animacija (prima signal od IGRAČA 1)
-   UI Overlay elementi:
-   Pop-up Ad (spawn, "X" klik za zatvaranje)
-   Cookie Banner (spawn od dole, "Accept All" dugme)
-   Notification Bell (mali, trepće ekran)
-   Software Update ("Later" dugme, freeze ako ne klikneš)
-   Chat Box (Twitch-style poruke, "Mute" dugme)
-   Error Dialog ("OK" dugme)
-   CAPTCHA (mini-puzzle za boss fight)
-   "Free iPhone" bait (klik = damage!)
-   Vizualni efekti:
-   CRT shader (scanlines, zakrivljenost)
-   Screen shake
-   RGB split efekat na visokom debris-u
-   Smrt animacija (BSOD)
-   Defrag animacija
-   Skor Multiplikator vizual (veliki tekst koji pokazuje trenutni multiplier)

**Zašto on**: Ovo je IDENTITET igre --- debris i UI overlay su ono što SCREENROT čini posebnim. Bez ovoga je samo generički shooter. Ovo je najkreativniji zadatak.

**Asset potrebe**:

-   UI elementi (može se napraviti u Godot-u sa Control čvorovima --- ne trebaju slike!)
-   Pop-up teksture --- mogu se napraviti od screenshot-ova pravih UI elemenata, stilizovanih
-   CRT shader --- postoji besplatno na Godot Shader repozitorijumu
-   Font za UI elemente (Arial/system font za "realne" UI elemente)

---

## IGRAČ 4: "META" --- Menije, Progresija, Audio, Polish

**Odgovornost**: Sve van gameplay-a + audio + tekst + polish.

**Konkretni taskovi**:

-   Main Menu:
-   Start Game, Upgrade Shop, Endless Mode (kad se otključa), Quit
-   SCREENROT logo/naslov
-   Upgrade Shop (Meta-Progression):
-   Shop UI sa karticama za svaki upgrade
-   Credit sistem (zarađivanje posle runa, trošenje u shopu)
-   Permanentni upgrade-ovi (HP+, Defrag cooldown, brzina...)
-   Save/Load sistem (čuvanje kupljenih upgrade-ova)
-   In-Run Upgrade ekran:
-   Posle svakog wave-a: prikaži 3 random upgrade-a
-   Igrač bira 1, primeni efekat
-   Baza od 12-18 upgrade-ova sa ikonama i opisima
-   Pause Menu
-   Game Over ekran (sa skorom, kreditima zarađenim, "Try Again" dugme)
-   Victory ekran (posle boss-a)
-   Audio integracija:
-   Pronalaženje i integracija muzike (free asset --- OpenGameArt, Freesound)
-   SFX integracija (pucanje, ubijanje, UI zvuci, Windows error zvuci)
-   Dinamička muzika (menjanje layer-a na osnovu debris %)
-   Humor tekst:
-   Pop-up poruke (15-20 varijacija)
-   Chat box poruke (20-30 varijacija)
-   Error dialog poruke (10 varijacija)
-   Boss death poruke
-   High Score sistem (lokalni)
-   Endless Mode logika (beskonačni wave-ovi + boss rotacija)

**Zašto on**: Svaka igra bez menija, progresije i zvuka deluje nedovršeno. Ovo je "lepak" koji sve drži na okupu. Takođe, audio i humor su ono što podiže ocene za Enjoyment i Audio kategorije.

**Asset potrebe**:

-   Muzika: Besplatan synthwave/chiptune --- pretraži OpenGameArt.org, Freesound.org, ili koristiti jsfxr/sfxr za SFX
-   SFX: Windows zvuci (lako se nađu besplatno), pucanje/eksplozije iz besplatnih paketa
-   Font: Pixel font za gameplay, system font za UI elemente
-   Ikone za upgrade-ove (može jednostavne emoji ili pixel ikone sa itch.io)

---

# TAJMLAJN --- 72 SATA

## FAZA 1: TEMELJ (Sati 0-8)

*Cilj: Bazični sistemi rade nezavisno.*

  Sat   IGRAČ 1 (Core)                                              IGRAČ 2 (Enemies)                           IGRAČ 3 (Screen)                                    IGRAČ 4 (Meta)
  ----- ----------------------------------------------------------- ------------------------------------------- --------------------------------------------------- -------------------------------------------------------------
  0-2   Setup projekat, kreiranje scene strukture, igrač kretanje   Enemy bazna klasa, kretanje ka igraču       CanvasLayer za debris, prvi debris test             Pronalaženje SVIH asseta (muzika, SFX, sprite-ovi, fontovi)
  2-4   Sistem pucanja (auto-fire, nišanjenje mišem)                Pixel Grunt AI + spawn na random poziciji   Pop-up Ad element (spawn + "X" klik)              Main Menu scena (Start, Quit)
  4-6   Collision: meci→neprijatelji, neprijatelji→igrač            Static Walker + Bit Bug AI                  Cookie Banner + Notification Bell                   In-run upgrade ekran UI (3 kartice, klik za izbor)
  6-8   HP sistem, smrt igrača, basic Game Over                     Wave Manager v1 (Wave 1 spawn pattern)      Debris generisanje na smrti neprijatelja (signal)   Game Over ekran + skor prikaz

**MILESTONE 1 (Sat 8)**: Igrač se kreće, puca, ubija neprijatelje u Wave 1, debris se pojavljuje, postoji meni. **PRVI PLAYTEST KAO TIM.**

---

## FAZA 2: INTEGRACIJA (Sati 8-20)

*Cilj: Sve se povezuje u jednu celinu. Igra je "igriva".*

  Sat     IGRAČ 1 (Core)                                 IGRAČ 2 (Enemies)                                                    IGRAČ 3 (Screen)                                   IGRAČ 4 (Meta)
  ------- ---------------------------------------------- -------------------------------------------------------------------- -------------------------------------------------- ---------------------------------------------------
  8-12    Defrag mehanika (SPACE, cooldown, čišćenje)    Glitch Dasher + Corruption Spawner AI                                UI overlay sistem (spawn manager za UI elemente)   Credit sistem + Upgrade Shop UI
  12-16   Skor sistem + Multiplikator logika             Wave 2 + Wave 3 spawn patterni                                       Software Update + Chat Box + Error Dialog          In-run upgrade logika (primena efekata na igrača)
  16-20   Integracija sa IGRAČ 3 (Defrag čisti debris)   Boss 1 "Bloatware" --- Faza 1 (kretanje + "Next>" projektili)   Debris % tracker + vizuelni feedback (boja bara)   Audio integracija v1 (muzika + basic SFX)

**MILESTONE 2 (Sat 20)**: 3 wave-a rade, debris + UI elementi se pojavljuju, Defrag radi, boss ima prvu fazu, postoji meni i upgrade shop. **DRUGI PLAYTEST + BALANSIRANJE.**

---

## FAZA 3: SADRŽAJ (Sati 20-40)

*Cilj: Igra ima dovoljno sadržaja da bude zabavna.*

  Sat     IGRAČ 1 (Core)                                                   IGRAČ 2 (Enemies)                                         IGRAČ 3 (Screen)                           IGRAČ 4 (Meta)
  ------- ---------------------------------------------------------------- --------------------------------------------------------- ------------------------------------------ ----------------------------------------------------------------
  20-26   Različita oružja (Scatter Gun, Laser) + weapon select pre runa   Boss 1 Faza 2 + Faza 3 (Terms & Conditions, Error spam)   CAPTCHA element + "Free iPhone" bait     Humor tekst (pop-up poruke, chat poruke, error poruke)
  26-32   Dash mehanika + Shield upgrade                                   Boss death animacija + tranzicija                         CRT shader + Screen shake + RGB split      Više in-run upgrade-ova (Ad Block, Dark Mode, Premium Account)
  32-40   Karakter sistem (različiti statovi)                              Firewall mini-boss (Wave 3) + Screen Eater                Defrag animacija (satisfying pixel sort)   Permanentni upgrade-ovi u shopu (6-8 upgrade-ova)

**MILESTONE 3 (Sat 40)**: Kompletna igra: 3 wave-a + boss sa 3 faze, 8+ in-run upgrade-a, shop sa permanentnim upgrade-ovima, audio, humor. **TREĆI PLAYTEST.**

---

## FAZA 4: POLISH (Sati 40-56)

*Cilj: Igra izgleda i zvuči profesionalno.*

  Sat     IGRAČ 1 (Core)                                       IGRAČ 2 (Enemies)                                                    IGRAČ 3 (Screen)                                            IGRAČ 4 (Meta)
  ------- ---------------------------------------------------- -------------------------------------------------------------------- ----------------------------------------------------------- ------------------------------------------------------
  40-48   Balansiranje (damage, HP, fire rate, cooldown-ovi)   Boss 2 "Social Feed" (ako ima vremena) ILI balansiranje wave-ova   Vizualni polish (particle efekti, glow, smooth animacije)   Dinamička muzika (layered audio baziran na debris %)
  48-56   Bug fixing + edge case handling                      Bug fixing + enemy balansiranje                                      BSOD smrt ekran + Boss ulaz animacija                       Victory ekran + Boss death poruke + High score tabla

**MILESTONE 4 (Sat 56)**: Polished igra spremna za submit. **ČETVRTI PLAYTEST SA NEKIM KO NIJE U TIMU.**

---

## FAZA 5: FINALIZACIJA (Sati 56-72)

*Cilj: Submit-ready build, bez kritičnih bagova.*

  Sat     SVI ZAJEDNO
  ------- -------------------
  56-62   Bug fixing na osnovu feedback-a od testera. Svi igraju i zapisuju bagove.
  62-66   Finalni balans pass. Endless Mode (ako ima vremena). Poslednji audio/vizualni detalji.
  66-70   Build za submit. Testiranje builda. Pisanje opisa za jam stranicu. Screenshot-ovi.
  70-72   **SUBMIT**. Proslava. 🎉

---

# KOMUNIKACIJA I WORKFLOW

## Git strategija

-   **Jedan repo, jedna main grana**
-   Svako radi na SVOJOJ SCENI --- ne dirajte tuđe scene!
-   IGRAČ 1: `player.tscn`, `bullet.tscn`, `arena.tscn`
-   IGRAČ 2: `enemies/` folder, `boss/` folder, `wave_manager.tscn`
-   IGRAČ 3: `debris/` folder, `ui_overlay/` folder, `effects/` folder
-   IGRAČ 4: `menus/` folder, `shop/` folder, `audio/` folder
-   **Main scena** (`game.tscn`): Samo IGRAČ 1 je menja, ostali dodaju svoje scene kao child čvorove
-   Commit i push ČESTO (minimum svaka 2 sata)
-   Ako se merge conflict desi --- zovi se na Discord/poziv i rešite zajedno

## Komunikacija između sistema (Signali u Godot-u)

Ovo je KLJUČNO --- sistemi komuniciraju preko Godot signala, ne direktnih referenci:

    IGRAČ 2 (Enemy umre)
        → signal: "enemy_killed(position, enemy_type)"
            → IGRAČ 3 prima signal → generiše debris/UI element na poziciji
            → IGRAČ 1 prima signal → dodaje skor × multiplikator
            → IGRAČ 4 prima signal → pušta SFX

    IGRAČ 1 (Defrag aktiviran)
        → signal: "defrag_activated"
            → IGRAČ 3 prima signal → čisti sav debris i UI
            → IGRAČ 4 prima signal → pušta defrag SFX

    IGRAČ 3 (Debris % promenjen)
        → signal: "debris_changed(percentage)"
            → IGRAČ 1 prima signal → ažurira multiplikator
            → IGRAČ 4 prima signal → menja muzički layer

    IGRAČ 1 (Igrač umro)
        → signal: "player_died(score, credits)"
            → IGRAČ 4 prima signal → prikazuje Game Over ekran

    IGRAČ 2 (Boss pobeđen)
        → signal: "boss_defeated(boss_id, score)"
            → IGRAČ 4 prima signal → prikazuje Victory ekran + kredite

    IGRAČ 1 (Wave završen)
        → signal: "wave_completed(wave_number)"
            → IGRAČ 4 prima signal → prikazuje upgrade izbor ekran
            → IGRAČ 2 prima signal → priprema sledeći wave/boss

## Dnevni check-in

-   **Početak dana**: 10min standup --- šta je urađeno, šta je plan, ima li blocker-a
-   **Sredina dana**: Quick sync --- playtest zajedno, feedback
-   **Kraj dana**: Merge sve na main, testiranje zajedničkog build-a

---

# ASSET LISTA --- ŠTA SKINUTI PRE POČETKA

Pre nego što počne jam, IGRAČ 4 treba da pripremi sve assete:

## Sprite-ovi (besplatni)

-   **Kenney.nl** --- "Pixel Shmup" pack ili "Tiny Dungeon" za bazne sprite-ove
-   **itch.io** --- pretraži "top down shooter pixel art free"
-   Za bosa: Može se napraviti od Godot Sprite2D čvorova (geometrijski oblici)

## Audio

-   **Muzika**: OpenGameArt.org → pretraži "synthwave", "chiptune", "retro arcade"
-   **SFX pucanje/eksplozije**: jsfxr.frozenfractal.com (generator retro zvukova)
-   **Windows zvuci**: Freesound.org → pretraži "windows error", "notification", "startup"
-   **UI zvuci**: Freesound.org → pretraži "click", "whoosh", "pop"

## Shaderi

-   **CRT shader**: godotshaders.com → pretraži "CRT" (ima ih više besplatnih)
-   **Glitch shader**: godotshaders.com → pretraži "glitch" ili "VHS"

## Fontovi

-   **Gameplay**: Pixel font --- "Press Start 2P" (besplatan na Google Fonts)
-   **UI elementi**: System font ili "Arial" za realistični izgled

---

# SAVETI ZA JAM

1.  **Scope je neprijatelj** --- bolje je imati 3 wave-a + 1 boss koji su POLISHED nego 10 wave-ova + 4 bossa koji su bagavi
2.  **Playtest RANO i ČESTO** --- ne čekajte sat 60 da testirate. Svaki milestone = playtest
3.  **Humor možete dodati u poslednjih 6 sati** --- pop-up tekst i chat poruke se dodaju brzo a masivno podižu Enjoyment ocenu
4.  **Audio je POSLEDNJI ali OBAVEZAN** --- igra bez zvuka gubi minimum 1-2 poena. Makar bazični SFX
5.  **Submit SAT PRE ROKA** --- uvek se desi nešto u poslednjem trenutku
6.  **Spavajte** --- 72h ne znači 72h rada. 3 noći po 5-6h sna = bolji kod nego 72h bez sna
