# TODO - Karta Ważenia WebApp
*Ostatnia aktualizacja: 23.04.2026*

## STATUS ZADAŃ

### ✅ ZROBIONE
- **3.** Zwrot schowany — mała szara linia, nie pełne pole
- **4.** Twardość < 4.5 → auto-zmiana przeznaczenia na Przecier przy zapisie + baner pod polem
- **15.** RYLEX/GRÓJECKA wzajemnie się wykluczają
- **Odpad** — bug z brakującym listenerem naprawiony, podgląd na żywo (−X kg → netto Y kg)
- **Etykieta** — czarno-białe (bez kolorów), QR wyśrodkowany
- **Watermark WSG** — skrzynka + liść w tle

---

### 🔲 DO ZROBIENIA (w kolejności)

**1.** Zmiana layoutu WSG — lepsza kolejność uzupełniania, czytelniejsze infografiki/watermarki

**2.** Odmiany przenieść wyżej i bardziej widoczne; "Drukuj etykiety" bardziej widoczne; blokada zapisu jeśli parametry puste (BRIX, ODPAD, TWARDOŚĆ muszą mieć cokolwiek, nawet 0)

**5.** Dwie+ odmiany → przy druku etykiety wybór której odmiany (1, 2, 3...) zamiast wszystkich naraz

**6.** Numer dostawy wyświetlać jako pełny LOT (np. C/0001/001/26) nie sam numer "2"

**7.** Zakładka Karty Ważenia — grupowanie pod jednym numerem bazowym (C/0001/001/26), rozwijanie dla odmian; suma netto, suma skrzyń, wszystkie odmiany obok siebie

**8.** W podglądzie karty — ukryj wagi aut jeśli nie ma drugiego auta; ukryj zwrot jeśli = 0

**9.** Edycja karty ważenia przez admina — synchronizacja z PS, PLS, wydrukiem

**10.** Stany surowcowe — rozciągnij na całość ekranu; zaokrąglenie kg na skrzynię bez miejsc po przecinku; PODSUMOWANIE MAGAZYNU filtruje się wg wybranego przeznaczenia

**11.** Skrzynie — akcja przyjęcia/wydania widoczna w historii; korekta skrzyń dla admina (zębatka → dodaj/odejmij/ustaw datę → pojawi się w akcjach jako "korekta")

**12.** PS (Parametry Surowca) — grupowanie pod jednym numerem, możliwość rozwinięcia

**13.** KWG — skrzynie MB (nie MBF); zwrot ukryty; dostawca MBF bez numeru 000; numer dostawy AUTO wg wzoru:
- Grójecka: W/001/2104/G (001=nr dostawy dnia, 2104=dzień+miesiąc, G=Grójecka)
- Rylex: W/001/2104/R
- Dać możliwość korekty ale domyślnie auto

**14.** KWG — dodaj odmiany (ile potrzeba); pole "Dodatkowe informacje" (np. skrzynie z różnych dostaw)

**16.** Stany → nowa zakładka "Dostawcy" — owoc → odmiany → łączne kg od dostawcy (np. Jonagold 004 - 20000 Świątek)

**17.** Usuń przycisk "Prześlij do stanów" — auto przy zapisie KW

**18.** Lista dostaw — zakładki: Wszystkie + Nierozliczone; przycisk "Rozlicz" usuwa z nierozliczonych

**19.** MCR zejście — ze Stanów surowcowych: wybierz owoc → odmianę → wagę lub ilość skrzyń → trafia do MCR jako zejście i odejmuje ze stanów

---

## PRIORYTET NASTĘPNEJ SESJI
Zacznij od: **2, 5, 6, 7, 8** — bo dotyczą głównego flow KW
