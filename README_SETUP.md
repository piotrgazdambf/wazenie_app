# System Ważenia — Flutter App

## Wymagania

- Flutter SDK 3.19+ → https://docs.flutter.dev/get-started/install/windows
- Konto Google (Firebase)
- Android Studio (dla emulatora) lub Chrome (web)

## Szybki start

```
1. Zainstaluj Flutter SDK i dodaj do PATH
2. Uruchom setup.bat (tworzy boilerplate + instaluje zależności)
3. Skonfiguruj Firebase (patrz niżej)
4. flutter run -d chrome
```

## Konfiguracja Firebase

### 1. Utwórz projekt Firebase
- Idź na https://console.firebase.google.com
- Utwórz nowy projekt (np. `wazenie-system`)
- Włącz **Firestore Database** (wybierz region: `europe-central2`)
- Włącz **Remote Config**

### 2. Wygeneruj firebase_options.dart
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=wazenie-system
```
Plik `lib/firebase_options.dart` zostanie nadpisany poprawnymi danymi.

### 3. Reguły Firestore (wklej w Firebase Console → Firestore → Rules)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Użytkownicy — tylko odczyt dla wszystkich (autoryzacja przez PIN w aplikacji)
    match /users/{userId} {
      allow read: if true;
      allow write: if false; // zarządzane przez Cloud Functions lub admin SDK
    }

    // Dostawy
    match /deliveries/{id} {
      allow read, write: if true; // dodaj weryfikację po wdrożeniu Firebase Auth
    }

    // PLS
    match /pls/{id} {
      allow read, write: if true;
    }

    // Kolejka MCR
    match /mcrQueue/{id} {
      allow read, write: if true;
    }

    // Konfiguracja
    match /appConfig/{id} {
      allow read: if true;
      allow write: if false;
    }

    // Magazyn
    match /inventory/{id} {
      allow read, write: if true;
    }
  }
}
```

> **Uwaga**: Reguły `allow read, write: if true` są tymczasowe.  
> W produkcji należy dodać Firebase Auth + weryfikację tokenu.

### 4. Remote Config — ustawienia wymagane
W Firebase Console → Remote Config dodaj parametry:

| Parametr | Typ | Wartość domyślna |
|----------|-----|-----------------|
| `min_version` | String | `1.0.0` |
| `maintenance_mode` | Boolean | `false` |
| `android_store_url` | String | (URL Play Store) |
| `ios_store_url` | String | (URL App Store) |

## Uruchomienie

```bash
# Web (Chrome)
flutter run -d chrome

# Android (emulator)
flutter run

# Build web (produkcja)
flutter build web --release

# Build Android APK
flutter build apk --release
```

## Struktura projektu

```
lib/
├── main.dart                    ← inicjalizacja Firebase, Hive, sesji
├── firebase_options.dart        ← wygenerowane przez flutterfire
├── app/
│   ├── router.dart              ← GoRouter + redirect logic
│   └── theme.dart               ← kolory i style
├── core/
│   ├── constants.dart           ← AppConstants, UserRole
│   ├── auth/
│   │   └── pin_auth_service.dart ← PIN hash, sesja, Firestore users
│   ├── firebase/
│   │   └── remote_config_service.dart ← force update
│   └── offline/
│       ├── offline_entry.dart   ← model wpisu offline
│       ├── hive_buffer.dart     ← lokalny bufor Hive
│       └── sync_manager.dart    ← auto-flush po powrocie internetu
├── features/
│   ├── auth/
│   │   └── pin_screen.dart      ← ekran PIN (wybór użytkownika + numpad)
│   ├── force_update/
│   │   └── force_update_screen.dart ← fullscreen overlay blokujący
│   └── home/
│       └── home_screen.dart     ← dashboard z modułami
└── shared/
    └── widgets/
        └── offline_banner.dart  ← banner offline + popup >10 wpisów
```

## Użytkownicy (automatyczny seed przy pierwszym uruchomieniu)

| Imię i nazwisko | PIN | Rola |
|-----------------|-----|------|
| Piotr Gazda | 3344 | Admin |
| Daryna Milinchuk | 0080 | User |
| Mariia Rymar | 5221 | User |

PIN zmieniany przez admina z poziomu aplikacji (Faza 6).

## Fazy implementacji

- [x] **Faza 1** — Fundament (Flutter + Firebase + PIN + force update + offline buffer)
- [ ] **Faza 2** — WSG + PLS + Firestore sync
- [ ] **Faza 3** — KW/KWG + PDKW + tabelki jakości
- [ ] **Faza 4** — ROZLICZENIE + MCR queue
- [ ] **Faza 5** — Python GAS Manager (auto-sync + code deploy)
- [ ] **Faza 6** — Stany + skrzynie + Zebra sync
- [ ] **Faza 7** — Admin panel + PINy
- [ ] **Faza 8** — Polish + CI/CD
