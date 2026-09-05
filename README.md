# 5passi - Live Map Tracker Mobile (Flutter) 🛰️📱

[![Built with Google Antigravity](https://img.shields.io/badge/Built%20with-Google%20Antigravity-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://deepmind.google)
[![Build and Release](https://github.com/alcio313/5passi/actions/workflows/build_and_release.yml/badge.svg)](https://github.com/alcio313/5passi/actions/workflows/build_and_release.yml)
[![Download APK](https://img.shields.io/badge/Download-APK%20Android-10B981?style=for-the-badge&logo=android&logoColor=white)](https://github.com/alcio313/5passi/releases)
[![Download IPA](https://img.shields.io/badge/Download-IPA%20iOS-00E5FF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/alcio313/5passi/releases)

Applicazione mobile nativa cross-platform in **Flutter** (`5passi`) per il tracciamento GPS in tempo reale tra gruppi, progettata per risolvere il limite del tracciamento a schermo spento delle Web App / PWA.

> 🤖 **Realizzato con Google Antigravity**: Questo progetto è stato interamente ideato, strutturato, sviluppato e ottimizzato con **Google Antigravity**, la piattaforma di sviluppo agentico avanzato di **Google DeepMind**.

---

## 📥 Download Pacchetti Compilati (Android & iOS)

Grazie a **GitHub Actions**, ad ogni aggiornamento del codice o rilascio di tag vengono automaticamente compilati nel cloud i pacchetti per dispositivi Android e iPhone:

* 📲 **[Scarica l'APK Diretto (Android)](https://github.com/alcio313/5passi/releases/download/latest/5passi-app-release.apk)** (installabile direttamente su qualsiasi smartphone/tablet Android senza passare dallo store).
* 🍏 **[Scarica il pacchetto IPA (iPhone / iOS)](https://github.com/alcio313/5passi/releases/download/latest/5passi-ios-unsigned.ipa)** (installabile su iPhone/iPad tramite AltStore, Sideloadly, TrollStore o Xcode).
* 📦 **[Scarica l'App Bundle (AAB)](https://github.com/alcio313/5passi/releases/download/latest/5passi-app-release.aab)** (pronto per la distribuzione su Google Play Console).
* 🏷️ Tutti i rilasci storici e gli archivi delle build sono disponibili nella sezione **[Releases](https://github.com/alcio313/5passi/releases)**.

---

## 🚀 Funzionalità Chiave

1. **Tracciamento a Schermo Spento (Continuous Background GPS)**:
   - **Android**: Esegue un *Foreground Service* nativo (`flutter_background_service`) con notifica persistente nella barra di stato e schermata di blocco. Il chip GNSS continua a campionare la posizione e ad inviarla via MQTT anche con lo smartphone bloccato in tasca.
   - **iOS**: Supporta le *Background Modes* di CoreLocation (`location`, `fetch`, `processing`), prevenendo la sospensione dell'app da parte del sistema operativo.
2. **Compatibilità 100% con la Web App PWA Esistente**:
   - Stesso algoritmo crittografico **End-to-End AES-GCM-256** con derivazione della chiave **PBKDF2 (100.000 round)**: utenti su app mobile e utenti su browser web possono trovarsi nella stessa stanza ed interagire con la massima sicurezza e riservatezza.
   - Stesso broker e formato dei topic MQTT (`broker.emqx.io`).
3. **Mappe Fluide ad Alta Risoluzione**:
   - Basate su `flutter_map` con tile CARTO Voyager e OpenStreetMap.
   - Marker fluorescente radar pulsante, scia spessa ad alta visibilità (6px) e controlli touch senior-friendly (pulsanti da 64px+).
4. **Algoritmo Batteria Eco & Filtro Haversine**:
   - Campionamento a duty-cycle cadenzato a 15 secondi.
   - Filtro di movimento matematico Haversine (ignora micro-spostamenti < 10 metri per azzerare il consumo radio e della batteria se l'utente è fermo).

---

## 📂 Architettura del Progetto

```
5passi/
├── .github/
│   └── workflows/
│       └── build_and_release.yml            # CI/CD automatica per compilazione APK/AAB
├── pubspec.yaml                             # Dipendenze Flutter
├── android/
│   ├── app/build.gradle.kts                 # Desugaring abilitato per Android
│   └── app/src/main/AndroidManifest.xml     # Permessi Foreground Service & Location
├── ios/
│   └── Runner/Info.plist                    # Permessi Location & Background Modes
└── lib/
    ├── main.dart                            # Avvio app & inizializzazione background service
    ├── core/
    │   ├── constants/                       # Palette colori WCAG e configurazioni
    │   └── utils/                           # Formula Haversine e slugify stanze
    ├── models/                              # Modelli LocationPoint, PeerUser, EncryptedPacket
    ├── services/
    │   ├── crypto_service.dart              # E2EE PBKDF2 + AES-GCM (WebCrypto compatibile)
    │   ├── mqtt_service.dart                # Client MQTT con auto-riconnessione
    │   ├── location_service.dart            # Geolocalizzazione nativa
    │   ├── background_service.dart          # Foreground Service Android & Isolate Dart
    │   └── feedback_service.dart            # Feedback aptico nativo (HapticFeedback)
    ├── providers/
    │   └── tracker_provider.dart            # Gestione reattiva dello stato
    └── ui/
        ├── screens/                         # JoinRoomScreen e TrackerMapScreen
        └── widgets/                         # TrackerMapView, RadarMarker, TrackingButton
```

---

## 🛠️ Come Avviare l'Applicazione in Locale

### Prerequisiti
* **Flutter SDK** (versione 3.0 o superiore): scaricabile da [flutter.dev](https://flutter.dev).
* **Android Studio** (per test su Android o emulatore) oppure **Xcode** (su macOS per iPhone).

### Comandi Rapidi

1. Clona il repository:
   ```bash
   git clone https://github.com/alcio313/5passi.git
   cd 5passi
   ```

2. Scarica le dipendenze:
   ```bash
   flutter pub get
   ```

3. Collega lo smartphone via USB o avvia un emulatore, poi esegui:
   ```bash
   flutter run
   ```

---

## 🔋 Note sul Risparmio Energetico su Android

Su alcuni dispositivi Android (in particolare Samsung, Xiaomi/MIUI e Huawei), il sistema operativo applica criteri di risparmio batteria molto aggressivi:
* Quando avvii il tracciamento per la prima volta, consenti il permesso di localizzazione impostandolo su **"Consenti sempre"** (non solo *"Mentre l'app è in uso"*).
* Nelle impostazioni della batteria del telefono, disattiva l'ottimizzazione batteria per l'app **5passi** (seleziona *"Senza restrizioni"*).
* La notifica fissa nella barra di stato garantisce che il sistema operativo non chiuda il processo quando la memoria RAM scarseggia.

---

## 🤖 Google Antigravity

Questo software è stato sviluppato in pair programming e generato con **Google Antigravity**, l'ambiente avanzato di sviluppo agentico AI di **Google DeepMind**.
