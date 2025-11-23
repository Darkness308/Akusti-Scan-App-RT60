# Akusti-Scan-App-RT60 - Complete Setup Guide

## 📱 Projektübersicht

**Akusti-Scan-App-RT60** ist eine iOS-Anwendung zur Messung akustischer Eigenschaften, speziell der RT60-Nachhallzeit (Reverberation Time). RT60 ist die Zeit, die benötigt wird, bis ein Schallsignal um 60 dB abklingt.

### Aktueller Status
- **Phase:** Initial Development (Skeleton/Template)
- **Version:** 1.0 (Build 1)
- **Erstellt:** 03.11.2025
- **Entwickler:** Marc Schneider-Handrup

## 🛠 Technologie-Stack

### Primäre Technologien
- **Sprache:** Swift 5.0
- **UI Framework:** SwiftUI
- **Build System:** Xcode 26.0.1
- **Minimum iOS Version:** iOS 26.0
- **Unterstützte Geräte:** iPhone & iPad (Universal)

### Testing Frameworks
- **Unit Tests:** Apple Testing Framework (modern `@Test` syntax)
- **UI Tests:** XCTest mit XCUIApplication
- **Performance:** XCTApplicationLaunchMetric

### Build Konfiguration
- **Bundle ID:** MSH.Akusti-Scan-App-RT60
- **Development Team:** L328QJ7426
- **Code Signing:** Automatic
- **Swift Version:** 5.0
- **C++ Standard:** gnu++20

## 📋 Systemvoraussetzungen

### Entwicklungsumgebung
- **macOS:** Aktuelle Version mit Xcode-Support
- **Xcode:** Version 26.0.1 oder kompatibel
- **iOS SDK:** iOS 26.0+
- **Git:** Versionskontrolle
- **Apple Developer Account:** Für Code Signing und Deployment

### Hardware
- **Mac:** Intel oder Apple Silicon
- **iOS Device/Simulator:** iOS 26.0+
- **RAM:** Mindestens 8 GB (16 GB empfohlen)
- **Speicher:** Mindestens 20 GB frei für Xcode und Simulatoren

## 🚀 Installation & Setup

### 1. Repository Klonen

```bash
git clone <repository-url> Akusti-Scan-App-RT60
cd Akusti-Scan-App-RT60
```

### 2. Projekt in Xcode öffnen

```bash
# Option 1: Projekt direkt öffnen
open Akusti-Scan-App-RT60.xcodeproj

# Option 2: Workspace öffnen
open Akusti-Scan-App-RT60.xcodeproj/project.xcworkspace
```

### 3. Development Team konfigurieren

1. Öffne **Xcode**
2. Wähle das Projekt in der Navigator-Sidebar
3. Wähle das Target **Akusti-Scan-App-RT60**
4. Gehe zu **Signing & Capabilities**
5. Wähle dein **Development Team**
6. Xcode wird automatisch ein Provisioning Profile erstellen

### 4. Simulator oder Device auswählen

- **Simulator:** Wähle aus der Device-Liste (z.B. "iPhone 15 Pro")
- **Physical Device:** Verbinde dein iOS-Gerät via USB und wähle es aus

### 5. Build & Run

```bash
# Tastenkombination in Xcode
⌘ + R  # Build und Run
⌘ + B  # Nur Build
```

Oder via Command Line:

```bash
xcodebuild -project Akusti-Scan-App-RT60.xcodeproj \
           -scheme Akusti-Scan-App-RT60 \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build
```

## 🧪 Tests ausführen

### Unit Tests

```bash
# In Xcode
⌘ + U  # Alle Tests ausführen

# Via Command Line
xcodebuild test \
    -project Akusti-Scan-App-RT60.xcodeproj \
    -scheme Akusti-Scan-App-RT60 \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### UI Tests

```bash
xcodebuild test \
    -project Akusti-Scan-App-RT60.xcodeproj \
    -scheme Akusti-Scan-App-RT60UITests \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Einzelne Tests ausführen

```bash
# Spezifischen Test ausführen
xcodebuild test \
    -project Akusti-Scan-App-RT60.xcodeproj \
    -scheme Akusti-Scan-App-RT60 \
    -only-testing:Akusti-Scan-App-RT60Tests/Akusti_Scan_App_RT60Tests/example
```

## 📁 Projektstruktur

```
Akusti-Scan-App-RT60/
├── Akusti-Scan-App-RT60/           # Main App Target
│   ├── Akusti_Scan_App_RT60App.swift   # App Entry Point (@main)
│   ├── ContentView.swift               # Main UI View
│   └── Assets.xcassets/                # Assets (Icons, Colors)
│       ├── AppIcon.appiconset/
│       └── AccentColor.colorset/
│
├── Akusti-Scan-App-RT60Tests/      # Unit Test Target
│   └── Akusti_Scan_App_RT60Tests.swift
│
├── Akusti-Scan-App-RT60UITests/    # UI Test Target
│   ├── Akusti_Scan_App_RT60UITests.swift
│   └── Akusti_Scan_App_RT60UITestsLaunchTests.swift
│
└── Akusti-Scan-App-RT60.xcodeproj/ # Xcode Project
    ├── project.pbxproj              # Build Configuration
    └── project.xcworkspace/
```

## 🏗 Build-Konfigurationen

### Debug Configuration
- **Optimization:** `-Onone` (Keine Optimierung)
- **Debug Symbols:** DWARF
- **Purpose:** Entwicklung und Debugging
- **Code Signing:** Development

### Release Configuration
- **Optimization:** `-O` (Volle Optimierung)
- **Debug Symbols:** DWARF with dSYM
- **Code Generation:** Whole Module Optimization
- **Purpose:** App Store Distribution
- **Code Signing:** Distribution

## 📦 Dependencies

**Aktuell:** Keine externen Dependencies

Das Projekt nutzt ausschließlich Apple's nativen Frameworks:
- SwiftUI (UI)
- Foundation (Core)
- Testing (Unit Tests)
- XCTest (UI Tests)

### Zukünftige Dependencies (für RT60-Implementierung)

Für die akustische Messung könnten folgende Frameworks relevant sein:
- **AVFoundation:** Audio Recording & Playback
- **Accelerate:** DSP (Digital Signal Processing)
- **CoreML:** Potentiell für ML-basierte Analyse

## 🔧 Entwicklungs-Workflow

### 1. Feature Branch erstellen

```bash
git checkout -b feature/your-feature-name
```

### 2. Entwicklung

- Implementiere Features
- Schreibe Tests
- Dokumentiere Code
- Teste auf Simulator & Device

### 3. Code Review

- Prüfe Code-Qualität
- Führe alle Tests aus
- Prüfe Performance

### 4. Commit & Push

```bash
git add .
git commit -m "Description of changes"
git push origin feature/your-feature-name
```

## 🎯 Nächste Schritte für RT60-Implementierung

### Phase 1: Core Audio Setup
1. **AVAudioEngine Integration**
   - Audio Session konfigurieren
   - Input Node Setup
   - Recording Pipeline

2. **Audio Permissions**
   - Privacy Info.plist Einträge
   - Permission Request Flow

### Phase 2: Signal Processing
1. **FFT Implementation**
   - Accelerate Framework nutzen
   - Frequency Analysis

2. **RT60 Calculation**
   - Schroeder Integration
   - Decay Curve Analysis
   - -60dB Detection

### Phase 3: UI/UX
1. **Recording Interface**
   - Start/Stop Controls
   - Real-time Feedback
   - Waveform Visualization

2. **Results Display**
   - RT60 Value
   - Frequency Band Analysis
   - Export Functionality

### Phase 4: Data Management
1. **Core Data / SwiftData**
   - Measurement History
   - Location Tags
   - Notes & Metadata

2. **Export Features**
   - CSV Export
   - PDF Reports
   - Cloud Sync (optional)

## 🔒 Sicherheit & Privacy

### Permissions Required
```xml
<!-- Info.plist Einträge -->
<key>NSMicrophoneUsageDescription</key>
<string>Diese App benötigt Zugriff auf das Mikrofon für akustische Messungen.</string>
```

### Best Practices
- ✅ User Consent vor Microphone-Zugriff
- ✅ Secure Data Storage (Keychain für sensitive Daten)
- ✅ No Analytics ohne User Consent
- ✅ Offline-First Approach (Privacy by Design)

## 📊 Testing-Strategie

### Unit Tests
- Business Logic
- RT60 Calculation Algorithms
- Data Model Validation
- Utilities & Helpers

### UI Tests
- User Flows
- Permission Handling
- Recording Workflow
- Results Display

### Performance Tests
- Launch Performance
- Audio Processing Speed
- Memory Usage
- Battery Impact

### Integration Tests
- Audio Pipeline
- File I/O
- Core Data Operations

## 🐛 Debugging & Troubleshooting

### Häufige Probleme

#### Code Signing Fehler
```
Solution: Xcode → Preferences → Accounts → Apple ID hinzufügen
         → Signing & Capabilities → Team auswählen
```

#### Simulator startet nicht
```bash
# Simulator Reset
xcrun simctl erase all
# Xcode Cache leeren
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Build Fehler
```bash
# Clean Build Folder
⌘ + Shift + K  # In Xcode
# Oder
xcodebuild clean
```

## 📚 Ressourcen & Dokumentation

### Apple Documentation
- [SwiftUI](https://developer.apple.com/documentation/swiftui/)
- [AVFoundation](https://developer.apple.com/documentation/avfoundation/)
- [Accelerate](https://developer.apple.com/documentation/accelerate/)
- [Testing](https://developer.apple.com/documentation/testing/)

### RT60 & Acoustics
- ISO 3382: Measurement of room acoustic parameters
- Schroeder Integration Method
- Impulse Response Analysis

### Best Practices
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/design/human-interface-guidelines/swiftui)
- [iOS App Architecture](https://developer.apple.com/documentation/xcode/organizing-your-app-for-long-term-maintainability)

## 🤝 Contributing

### Code Style
- **Indentation:** 4 Spaces
- **Line Length:** Max 120 Zeichen
- **Naming:** SwiftLint konform
- **Documentation:** Swift DocC Format

### Commit Messages
```
feat: Add new feature
fix: Bug fix
docs: Documentation
test: Add tests
refactor: Code refactoring
perf: Performance improvement
style: Code style changes
```

## 📝 Lizenz

Proprietary - Marc Schneider-Handrup

## 👥 Kontakt & Support

**Developer:** Marc Schneider-Handrup
**Created:** November 3, 2025
**Bundle ID:** MSH.Akusti-Scan-App-RT60

---

**Version:** 1.0
**Last Updated:** November 23, 2025
