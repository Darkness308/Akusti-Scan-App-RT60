# 🎵 Akusti-Scan-App-RT60

Eine professionelle iOS-App zur Messung akustischer Raumeigenschaften mit Fokus auf RT60 (Nachhallzeit).

[![Platform](https://img.shields.io/badge/platform-iOS%2026.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

---

## 📖 Über das Projekt

**Akusti-Scan-App-RT60** ist eine iOS-Anwendung zur professionellen Messung der Nachhallzeit (RT60) in Räumen. RT60 ist die Zeit, die ein Schallsignal benötigt, um um 60 dB abzuklingen - ein wichtiger Parameter in der Akustik.

### Hauptfunktionen

- ✅ 🎤 **Audio-Aufnahme** mit hoher Qualität
- ✅ 📊 **RT60-Berechnung** für verschiedene Frequenzbänder (125 Hz - 4 kHz)
- ✅ 📈 **Visualisierung** von Decay-Kurven mit Regressionslinien
- ✅ 💾 **Messhistorie** mit lokaler Persistenz
- ✅ 📤 **Export** der Messergebnisse als Text
- ✅ 🎯 **Raumtyp-Bewertung** mit optimalen RT60-Bereichen
- ✅ 📱 **Offline-First** Approach (keine Cloud erforderlich)
- 🔜 **PDF-Export** mit detaillierten Berichten
- 🔜 **Geo-Tagging** von Messungen

### Anwendungsfälle

- **Raumakustik-Analyse** für Tonstudios, Konzerthallen, Klassenzimmer
- **Bauakustik** zur Qualitätskontrolle
- **Forschung & Lehre** in Audio Engineering
- **DIY Audio** für Heimkino und Hi-Fi Enthusiasten

---

## 🚀 Quick Start

### Voraussetzungen

- macOS mit Xcode 26.0.1+
- iOS 26.0+ SDK
- Apple Developer Account (für Code Signing)
- Git

### Installation

```bash
# Repository klonen
git clone <repository-url>
cd Akusti-Scan-App-RT60

# Projekt öffnen
open Akusti-Scan-App-RT60.xcodeproj

# In Xcode: Signing & Capabilities konfigurieren
# Build & Run: ⌘ + R
```

### Erste Schritte

1. **Simulator auswählen** oder **iOS-Gerät** anschließen
2. **Build & Run** (⌘ + R)
3. **Mikrofonzugriff erlauben** (erste App-Start)
4. **Messung starten** und akustische Daten sammeln

---

## 📁 Projektstruktur

```
Akusti-Scan-App-RT60/
│
├── 📄 README.md                    # Dieses Dokument
├── 📄 SETUP.md                     # Detaillierte Setup-Anleitung
├── 📄 CODE_REVIEW.md               # Code-Review Ergebnisse
├── 📄 ARCHITECTURE.md              # Architektur-Design
├── 📄 BEST_PRACTICES.md            # Best Practices Guide
│
├── 📱 Akusti-Scan-App-RT60/        # Main App
│   ├── Akusti_Scan_App_RT60App.swift
│   ├── ContentView.swift
│   ├── Models/                      # Data Models
│   │   └── RT60Measurement.swift
│   ├── ViewModels/                  # View Models (MVVM)
│   │   └── RT60ViewModel.swift
│   ├── Services/                    # Business Logic
│   │   ├── AudioRecorder.swift
│   │   └── RT60Calculator.swift
│   └── Assets.xcassets/
│
├── 🧪 Akusti-Scan-App-RT60Tests/   # Unit Tests
│   └── Akusti_Scan_App_RT60Tests.swift
│
└── 🎭 Akusti-Scan-App-RT60UITests/ # UI Tests
    ├── Akusti_Scan_App_RT60UITests.swift
    └── Akusti_Scan_App_RT60UITestsLaunchTests.swift
```

---

## 🏗 Architektur

Das Projekt folgt einer **MVVM + Clean Architecture**:

```
┌─────────────────────────────────────┐
│      Presentation Layer              │
│   (Views, ViewModels, UI State)     │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│        Domain Layer                  │
│  (Entities, Use Cases, Protocols)   │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│         Data Layer                   │
│ (Repositories, Services, Storage)   │
└─────────────────────────────────────┘
```

**Mehr Details:** Siehe [ARCHITECTURE.md](ARCHITECTURE.md)

---

## 🧪 Testing

### Unit Tests ausführen

```bash
# In Xcode
⌘ + U

# Via xcodebuild
xcodebuild test \
    -project Akusti-Scan-App-RT60.xcodeproj \
    -scheme Akusti-Scan-App-RT60 \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### UI Tests ausführen

```bash
xcodebuild test \
    -project Akusti-Scan-App-RT60.xcodeproj \
    -scheme Akusti-Scan-App-RT60UITests \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test Coverage

- **Ziel:** >80% Code Coverage
- **CI/CD:** Tests laufen automatisch bei jedem Push
- **Reports:** Test-Reports in `fastlane/test_output/`

---

## 🛠 Technologie-Stack

### Core Technologies

| Kategorie | Technologie | Version |
|-----------|-------------|---------|
| Sprache | Swift | 5.0+ |
| UI Framework | SwiftUI | iOS 26.0+ |
| Audio | AVFoundation | Native |
| DSP | Accelerate | Native |
| Storage | CoreData | Native |
| Testing | XCTest + Testing | Native |

### Build Tools

- **Xcode:** 26.0.1
- **Swift Package Manager:** Dependencies (zukünftig)
- **SwiftLint:** Code Quality
- **Fastlane:** CI/CD (geplant)

### Keine externen Dependencies

Das Projekt nutzt ausschließlich Apple's native Frameworks für:
- ✅ Maximale Performance
- ✅ Minimale App-Größe
- ✅ Langfristige Wartbarkeit
- ✅ Privacy by Design

---

## 📊 RT60 Berechnung - Technischer Hintergrund

### Was ist RT60?

**RT60 (Reverberation Time)** ist die Zeit, die ein Schallsignal benötigt, um von seiner ursprünglichen Lautstärke um 60 Dezibel (dB) abzufallen.

```
Amplitude (dB)
    0 dB │     ╱╲
         │    ╱  ╲
  -20 dB │   ╱    ╲___
         │  ╱         ╲___
  -40 dB │ ╱              ╲___
         │╱                   ╲___
  -60 dB │                        ╲___
         └─────────────────────────────→ Zeit
         0s                      RT60
```

### Frequenzbänder

Die App misst RT60 in 7 Oktav-Bändern:

| Band | Center Freq | Range |
|------|-------------|-------|
| 1 | 125 Hz | 88 - 177 Hz |
| 2 | 250 Hz | 177 - 354 Hz |
| 3 | 500 Hz | 354 - 707 Hz |
| 4 | 1000 Hz | 707 - 1414 Hz |
| 5 | 2000 Hz | 1414 - 2828 Hz |
| 6 | 4000 Hz | 2828 - 5657 Hz |
| 7 | 8000 Hz | 5657 - 11314 Hz |

### Berechnungsmethode

Die App nutzt die **Schroeder Integration Method**:

1. **Impulse Response** aufnehmen/generieren
2. **Quadrieren** des Signals: `h²(t)`
3. **Rückwärts-Integration:** `∫[t→∞] h²(τ) dτ`
4. **Konvertierung zu dB:** `10 * log10(integral)`
5. **Lineare Regression** im -5dB bis -35dB Bereich
6. **Extrapolation** auf -60dB

**Formel:**
```
RT60 = 60 / |slope|
```

Wobei `slope` die Steigung der Decay-Kurve ist.

---

## 📝 Development Workflow

### 1. Feature Branch erstellen

```bash
git checkout -b feature/your-feature-name
```

### 2. Entwickeln & Testen

```bash
# SwiftLint ausführen
swiftlint

# Tests ausführen
⌘ + U (in Xcode)

# Build
⌘ + B
```

### 3. Commit & Push

```bash
git add .
git commit -m "feat: Add RT60 calculation for 125 Hz band"
git push origin feature/your-feature-name
```

### 4. Pull Request erstellen

- **Titel:** Kurze Beschreibung
- **Beschreibung:** Was, warum, wie
- **Tests:** Alle Tests müssen grün sein
- **Review:** Mindestens 1 Approval erforderlich

---

## 🔒 Privacy & Sicherheit

### Berechtigungen

Die App benötigt:

- ✅ **Mikrofon-Zugriff** (NSMicrophoneUsageDescription)
- 🔜 **Standort** (optional, für Geo-Tagging)

### Datenschutz

- **Offline-First:** Keine Cloud-Uploads ohne Zustimmung
- **Lokale Speicherung:** Alle Messungen lokal in CoreData
- **Keine Tracking:** Kein Analytics ohne Opt-in
- **DSGVO-konform:** Privacy by Design

### Sicherheit

- **Code Signing:** Automatisch via Xcode
- **Keychain:** Für sensible Daten (zukünftig)
- **App Transport Security:** HTTPS only
- **Input Validation:** Alle Audio-Eingaben validiert

---

## 🎯 Roadmap

### v1.0 (MVP) - Q1 2026
- ✅ Projekt-Setup
- 🔜 Audio-Aufnahme
- 🔜 RT60-Berechnung (1 Frequenzband)
- 🔜 Einfache Visualisierung
- 🔜 Basis-UI

### v1.1 - Q2 2026
- 🔜 Alle 7 Frequenzbänder
- 🔜 Messhistorie
- 🔜 CSV Export
- 🔜 Dark Mode

### v2.0 - Q3 2026
- 🔜 Erweiterte Visualisierung
- 🔜 PDF Reports
- 🔜 Geo-Tagging
- 🔜 Raum-Klassifikation

### v3.0 - Future
- 🔜 Cloud Sync (optional)
- 🔜 Collaboration Features
- 🔜 AR Room Visualization
- 🔜 ML-basierte Analyse

---

## 👥 Team & Kontakt

**Entwickler:** Marc Schneider-Handrup

**Bundle ID:** MSH.Akusti-Scan-App-RT60

**Development Team:** L328QJ7426

**Erstellt:** 03.11.2025

---

## 📚 Dokumentation

- 📘 [**SETUP.md**](SETUP.md) - Komplette Setup-Anleitung
- 📗 [**ARCHITECTURE.md**](ARCHITECTURE.md) - Architektur-Design
- 📙 [**CODE_REVIEW.md**](CODE_REVIEW.md) - Code-Review Ergebnisse
- 📕 [**BEST_PRACTICES.md**](BEST_PRACTICES.md) - Best Practices Guide

### Externe Ressourcen

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift.org](https://swift.org/)
- [AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [Accelerate Framework](https://developer.apple.com/documentation/accelerate/)
- [ISO 3382](https://en.wikipedia.org/wiki/ISO_3382) - Measurement of room acoustic parameters

---

## 🤝 Contributing

Aktuell ist dies ein proprietäres Projekt. Contributions sind willkommen nach Absprache.

### Code Style

- **SwiftLint:** Siehe `.swiftlint.yml`
- **Formatting:** Xcode Standard
- **Comments:** Swift DocC Format
- **Tests:** Pflicht für neue Features

### Commit Conventions

Wir folgen [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: Add new feature
fix: Bug fix
docs: Documentation
test: Add tests
refactor: Code refactoring
perf: Performance improvement
style: Code style changes
chore: Maintenance tasks
```

---

## 📄 Lizenz

**Proprietary** - © 2025 Marc Schneider-Handrup

Alle Rechte vorbehalten.

---

## 🙏 Danksagungen

- **Apple** für SwiftUI und Accelerate Framework
- **Akustik-Community** für wissenschaftliche Grundlagen
- **Open Source Community** für Inspiration

---

## 📞 Support & Feedback

- **Issues:** GitHub Issues
- **Fragen:** Kontakt via GitHub
- **Feature Requests:** GitHub Discussions

---

**⭐ Wenn dir das Projekt gefällt, gib uns einen Star!**

---

**Version:** 1.0.0
**Last Updated:** 23.11.2025
**Status:** 🚧 In Development
