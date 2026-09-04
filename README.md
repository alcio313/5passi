# 5passi - Live Map Tracker Mobile (Flutter) 🛰️📱

Applicazione mobile nativa cross-platform in **Flutter** (`5passi`) per il tracciamento GPS in tempo reale tra gruppi, progettata per risolvere il limite del tracciamento a schermo spento delle Web App / PWA.

---

## 🚀 Funzionalità Chiave

1. **Tracciamento a Schermo Spento (Background Location)**:
   - **Android**: Esegue un *Foreground Service* nativo (`flutter_background_service`) con notifica persistente nella barra di stato e blocco schermo. Continua a campionare il GPS e inviare la posizione via MQTT anche con lo smartphone bloccato in tasca.
   - **iOS**: Supporta i *Background Modes* di CoreLocation (`location`, `fetch`, `processing`), mantenendo attivo l'invio della posizione senza sospensioni di sistema.
2. **Compatibilità 100% con la Web App PWA Esistente**:
   - Stesso algoritmo di crittografia **End-to-End AES-GCM-256** con derivazione della chiave **PBKDF2 (100.000 round)**: utenti su app mobile e utenti su browser web possono stare nella stessa stanza ed interagire con massima sicurezza.
   - Stesso broker e topic MQTT (`broker.emqx.io`).
3. **Mappe Fluide ad Alta Risoluzione**:
   - Basate su `flutter_map` con tile CARTO Voyager e OpenStreetMap.
   - Marker fluorescente radar pulsante, scia spessa ad alta visibilità e controlli touch senior-friendly (pulsanti grandi da 60px+).
4. **Algoritmo Batteria Eco & Filtro Haversine**:
   - Campionamento intelligente ogni 15 secondi.
   - Micro-spostamenti inferiori a 10 metri ignorati per preservare la carica della batteria e la banda di rete.

---

## 📂 Architettura del Progetto

```
flutter_tracker/
├── pubspec.yaml                             # Dipendenze Flutter
├── android/
│   └── app/src/main/AndroidManifest.xml     # Permessi Foreground Service & Location
├── ios/
│   └── Runner/Info.plist                    # Permessi Location & Background Modes
└── lib/
    ├── main.dart                            # Avvio app & inizializzazione background service
    ├── core/
    │   ├── constants/                       # Palette colori e configurazioni (MQTT, CARTO, GPS)
    │   └── utils/                           # Formula Haversine e slugify nomi stanza
    ├── models/                              # Modelli LocationPoint, PeerUser, EncryptedPacket
    ├── services/
    │   ├── crypto_service.dart              # E2EE PBKDF2 + AES-GCM (WebCrypto compatibile)
    │   ├── mqtt_service.dart                # Client MQTT con auto-riconnessione
    │   ├── location_service.dart            # Geolocalizzazione nativa
    │   ├── background_service.dart          # Foreground Service & Background Isolate
    │   └── feedback_service.dart            # Feedback aptico (vibrazione)
    ├── providers/
    │   └── tracker_provider.dart            # Gestione reattiva dello stato
    └── ui/
        ├── screens/                         # JoinRoomScreen e TrackerMapScreen
        └── widgets/                         # TrackerMapView, RadarMarker, TrackingButton
```

---

## 🛠️ Come Avviare l'Applicazione

### Prerequisiti
* **Flutter SDK** (versione 3.0 o superiore): scaricabile da [flutter.dev](https://flutter.dev).
* **Android Studio** (per test su Android o emulatore) oppure **Xcode** (su macOS per iPhone).

### Comandi Rapidi

1. Spostati nella cartella del progetto Flutter:
   ```bash
   cd flutter_tracker
   ```

2. Scarica i pacchetti e le dipendenze:
   ```bash
   flutter pub get
   ```

3. Collega lo smartphone via USB (con Debug USB attivo) o avvia un emulatore, poi esegui:
   ```bash
   flutter run
   ```

---

## 🔋 Note sul Risparmio Energetico su Android

Su alcuni dispositivi Android (in particolare Samsung, Xiaomi/MIUI e Huawei), il sistema operativo applica criteri di risparmio batteria molto aggressivi:
* Quando avvii il tracciamento per la prima volta, consenti il permesso di localizzazione impostandolo su **"Consenti sempre"** (non solo "Mentre l'app è in uso").
* Nelle impostazioni della batteria del telefono, disattiva l'ottimizzazione batteria per l'app **Live Map Tracker** (seleziona *"Senza restrizioni"*).
* La notifica fissa nella barra di stato garantisce che il sistema operativo non chiuda il processo quando la memoria RAM scarseggia.
