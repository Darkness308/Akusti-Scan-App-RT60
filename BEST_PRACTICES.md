# Best Practices Guide - Akusti-Scan-App-RT60

Ein umfassender Leitfaden für Entwicklung, Code-Qualität und Wartung.

---

## 📋 Inhaltsverzeichnis

1. [Swift & SwiftUI Best Practices](#1-swift--swiftui-best-practices)
2. [Architektur & Design Patterns](#2-architektur--design-patterns)
3. [Testing](#3-testing)
4. [Performance](#4-performance)
5. [Audio & DSP](#5-audio--dsp)
6. [Sicherheit & Privacy](#6-sicherheit--privacy)
7. [Git & Version Control](#7-git--version-control)
8. [Code Review](#8-code-review)
9. [Accessibility](#9-accessibility)
10. [Dokumentation](#10-dokumentation)

---

## 1. Swift & SwiftUI Best Practices

### 1.1 Naming Conventions

```swift
// ✅ GOOD
struct MeasurementViewModel { }
func calculateRT60(from sample: AudioSample) -> RT60Result { }
let maximumRecordingDuration: TimeInterval = 60.0

// ❌ BAD
struct VM { }
func calc(s: AudioSample) -> RT60Result { }
let maxDur = 60.0
```

**Regeln:**
- **Klassen/Structs:** PascalCase, beschreibend
- **Funktionen/Variablen:** camelCase, Verben für Aktionen
- **Konstanten:** camelCase (nicht SCREAMING_CASE)
- **Enums:** PascalCase für Type, camelCase für cases

### 1.2 SwiftUI View-Struktur

```swift
// ✅ GOOD - Klare Struktur
struct MeasurementView: View {
    @StateObject private var viewModel: MeasurementViewModel

    var body: some View {
        contentView
    }

    // MARK: - Subviews
    private var contentView: some View {
        VStack(spacing: 20) {
            headerView
            controlsView
            resultsView
        }
    }

    private var headerView: some View {
        Text("RT60 Messung")
            .font(.title)
            .fontWeight(.bold)
    }

    private var controlsView: some View {
        RecordingControlsView(viewModel: viewModel)
    }

    private var resultsView: some View {
        if let results = viewModel.rt60Results {
            RT60ResultView(results: results)
        }
    }
}

// ❌ BAD - Alles im body
struct MeasurementView: View {
    var body: some View {
        VStack {
            Text("RT60 Messung").font(.title).fontWeight(.bold)
            Button(action: { /* ... */ }) { /* ... */ }
            if let results = viewModel.rt60Results {
                ForEach(results) { /* ... */ }
            }
        }
    }
}
```

**Regeln:**
- **Extrahiere Subviews** für bessere Lesbarkeit
- **Nutze `private var`** für View-Komponenten
- **MARK-Kommentare** zur Strukturierung
- **Maximale Verschachtelungstiefe:** 3 Ebenen

### 1.3 Property Wrappers

```swift
// ✅ GOOD - Richtige Wrapper-Wahl
struct ContentView: View {
    @StateObject private var viewModel: MeasurementViewModel  // Ownership
    @ObservedObject var sharedManager: AudioManager          // Shared reference
    @State private var isShowingSettings = false             // Local state
    @Binding var selectedTab: Int                            // Two-way binding
    @Environment(\.dismiss) private var dismiss              // Environment
    @AppStorage("userPreference") var preference = true      // UserDefaults

    var body: some View {
        // ...
    }
}

// ❌ BAD - Falsche Wrapper
struct ContentView: View {
    @ObservedObject var viewModel: MeasurementViewModel  // ❌ Memory leak risk
    @State var sharedManager: AudioManager               // ❌ Wrong wrapper
}
```

**Regeln:**
- **@StateObject:** Für selbst erstellte ObservableObjects
- **@ObservedObject:** Für injizierte ObservableObjects
- **@State:** Für lokale, einfache Werte
- **@Binding:** Für Two-Way Data Binding
- **@Environment:** Für System-Environment Werte

### 1.4 Async/Await

```swift
// ✅ GOOD - Strukturiertes Error Handling
@MainActor
func startMeasurement() async {
    do {
        state = .recording
        let sample = try await recordAudio()

        state = .processing
        let results = try await calculateRT60(from: sample)

        state = .completed
        self.results = results
    } catch let error as AudioError {
        handleAudioError(error)
    } catch let error as RT60Error {
        handleRT60Error(error)
    } catch {
        handleGenericError(error)
    }
}

// ❌ BAD - Keine Error-Behandlung
func startMeasurement() async {
    state = .recording
    let sample = try! await recordAudio()  // ❌ force try
    let results = try! await calculateRT60(from: sample)
    self.results = results
}
```

**Regeln:**
- **Nie `try!`** in Production Code
- **Spezifische Fehlerbehandlung** vor Generic
- **@MainActor** für UI-Updates
- **Task.detached** für heavy computation

---

## 2. Architektur & Design Patterns

### 2.1 MVVM Pattern

```swift
// ✅ GOOD - Clean MVVM
// View
struct MeasurementView: View {
    @StateObject private var viewModel: MeasurementViewModel

    var body: some View {
        VStack {
            Text("RT60: \(viewModel.rt60Value)")
            Button("Record") {
                viewModel.startRecording()  // View calls ViewModel
            }
        }
    }
}

// ViewModel
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published var rt60Value: Double = 0

    private let calculateRT60UseCase: CalculateRT60UseCase

    func startRecording() {
        // Business logic here
        Task {
            let result = try await calculateRT60UseCase.execute()
            self.rt60Value = result.value
        }
    }
}

// ❌ BAD - Business Logic in View
struct MeasurementView: View {
    @State private var rt60Value: Double = 0

    var body: some View {
        Button("Record") {
            // ❌ Business logic in View
            let audioEngine = AVAudioEngine()
            audioEngine.start()
            // ... complex logic
        }
    }
}
```

**Regeln:**
- **Views:** Nur UI, keine Business Logic
- **ViewModels:** Business Logic & State Management
- **Models:** Reine Daten, keine Logic
- **Use Cases:** Wiederverwendbare Business Logic

### 2.2 Dependency Injection

```swift
// ✅ GOOD - Constructor Injection
final class MeasurementViewModel: ObservableObject {
    private let recordAudioUseCase: RecordAudioUseCase
    private let calculateRT60UseCase: CalculateRT60UseCase

    init(
        recordAudioUseCase: RecordAudioUseCase,
        calculateRT60UseCase: CalculateRT60UseCase
    ) {
        self.recordAudioUseCase = recordAudioUseCase
        self.calculateRT60UseCase = calculateRT60UseCase
    }
}

// Usage
let viewModel = MeasurementViewModel(
    recordAudioUseCase: container.recordAudioUseCase,
    calculateRT60UseCase: container.calculateRT60UseCase
)

// ❌ BAD - Tight Coupling
final class MeasurementViewModel: ObservableObject {
    private let recorder = AudioRecorder()  // ❌ Direct instantiation
    private let calculator = RT60Calculator()

    init() { }
}
```

**Regeln:**
- **Constructor Injection** bevorzugen
- **Protocols** für Abstraktion
- **DependencyContainer** für Produktion
- **Mock Implementations** für Tests

### 2.3 Protocol-Oriented Programming

```swift
// ✅ GOOD - Protocol + Implementation
protocol RT60Calculator {
    func calculate(from sample: AudioSample) async throws -> RT60Result
}

final class SchroederRT60Calculator: RT60Calculator {
    func calculate(from sample: AudioSample) async throws -> RT60Result {
        // Schroeder implementation
    }
}

final class MLBasedRT60Calculator: RT60Calculator {
    func calculate(from sample: AudioSample) async throws -> RT60Result {
        // ML implementation
    }
}

// Easy to test with mocks
final class MockRT60Calculator: RT60Calculator {
    var mockResult: RT60Result?

    func calculate(from sample: AudioSample) async throws -> RT60Result {
        guard let result = mockResult else {
            throw RT60Error.mockNotConfigured
        }
        return result
    }
}

// ❌ BAD - Konkrete Klasse ohne Protocol
final class RT60Calculator {
    func calculate(from sample: AudioSample) async throws -> RT60Result {
        // Implementation
    }
}
```

**Regeln:**
- **Protocols** für alle wichtigen Komponenten
- **Austauschbare Implementierungen**
- **Einfachere Tests** durch Mocks
- **Composition over Inheritance**

---

## 3. Testing

### 3.1 Unit Test Struktur

```swift
// ✅ GOOD - AAA Pattern (Arrange, Act, Assert)
import Testing
@testable import Akusti_Scan_App_RT60

@Suite("RT60 Calculation Tests")
struct RT60CalculationTests {

    @Test("Calculate RT60 from valid impulse response")
    func testValidImpulseResponse() async throws {
        // Arrange
        let impulseResponse = generateTestImpulse(frequency: 1000, decay: 0.5)
        let calculator = SchroederRT60Calculator()

        // Act
        let result = try await calculator.calculate(from: impulseResponse)

        // Assert
        #expect(result.value > 0)
        #expect(result.value < 10.0)
        #expect(result.confidence > 0.8)
    }

    @Test("Throw error for empty input")
    func testEmptyInput() async throws {
        // Arrange
        let calculator = SchroederRT60Calculator()
        let emptyInput = AudioSample(buffer: [], sampleRate: 48000, duration: 0, channelCount: 1)

        // Act & Assert
        await #expect(throws: RT60Error.invalidInput) {
            try await calculator.calculate(from: emptyInput)
        }
    }
}

// ❌ BAD - Unstrukturiert
func testRT60() async throws {
    let calculator = SchroederRT60Calculator()
    let result = try await calculator.calculate(from: generateTestImpulse(frequency: 1000, decay: 0.5))
    #expect(result.value > 0)  // Was wird getestet?
}
```

**Regeln:**
- **AAA Pattern:** Arrange, Act, Assert
- **Sprechende Namen:** Was wird getestet?
- **Ein Konzept pro Test**
- **@Suite** für Gruppierung
- **Test Helpers** für Wiederverwendung

### 3.2 Test Coverage Ziele

| Kategorie | Min. Coverage | Ziel Coverage |
|-----------|---------------|---------------|
| Domain Layer (Business Logic) | 90% | 100% |
| Data Layer (Repositories) | 80% | 90% |
| Presentation Layer (ViewModels) | 70% | 85% |
| UI Layer (Views) | 50% | 70% |
| **Gesamt** | **80%** | **90%** |

### 3.3 Mock Objects

```swift
// ✅ GOOD - Testable Mock
final class MockAudioRepository: AudioRepositoryProtocol {
    var shouldSucceed = true
    var recordedSample: AudioSample?
    var requestPermissionCallCount = 0

    func requestMicrophonePermission() async -> Bool {
        requestPermissionCallCount += 1
        return shouldSucceed
    }

    func startRecording() async throws {
        guard shouldSucceed else {
            throw AudioError.recordingFailed
        }
    }

    func stopRecording() async throws -> AudioSample {
        guard shouldSucceed else {
            throw AudioError.noData
        }
        return recordedSample ?? AudioSample.mock()
    }
}

// Usage in test
@Test("Handle recording failure")
func testRecordingFailure() async throws {
    let mockRepo = MockAudioRepository()
    mockRepo.shouldSucceed = false

    let useCase = RecordAudioUseCaseImpl(repository: mockRepo)

    await #expect(throws: AudioError.recordingFailed) {
        try await useCase.startRecording()
    }
}
```

---

## 4. Performance

### 4.1 Audio Processing Optimierung

```swift
// ✅ GOOD - Accelerate Framework nutzen
import Accelerate

func calculateEnergy(signal: [Float]) -> Float {
    var energy: Float = 0

    // Vectorized operation (fast!)
    vDSP_svesq(signal, 1, &energy, vDSP_Length(signal.count))

    return energy
}

// ❌ BAD - Loop (slow!)
func calculateEnergy(signal: [Float]) -> Float {
    var energy: Float = 0

    for sample in signal {
        energy += sample * sample
    }

    return energy
}
```

**Performance-Vergleich:**
- Accelerate: **~0.1ms** für 1M samples
- Loop: **~10ms** für 1M samples
- **100x schneller!**

### 4.2 Memory Management

```swift
// ✅ GOOD - Streaming große Dateien
func processLargeAudioFile(url: URL) async throws {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let chunkSize: AVAudioFrameCount = 4096

    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize)!

    while file.framePosition < file.length {
        try file.read(into: buffer, frameCount: chunkSize)
        processChunk(buffer)  // Process immediately, don't accumulate
    }
}

// ❌ BAD - Alles in Memory laden
func processLargeAudioFile(url: URL) async throws {
    let file = try AVAudioFile(forReading: url)
    let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: AVAudioFrameCount(file.length)  // ❌ Huge allocation!
    )!
    try file.read(into: buffer)
    processAllAtOnce(buffer)
}
```

### 4.3 UI Performance

```swift
// ✅ GOOD - Offload heavy work
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published var results: [RT60Result]?

    func calculateRT60() {
        Task.detached {  // Background thread
            let results = await self.performHeavyCalculation()

            await MainActor.run {  // Update UI on main thread
                self.results = results
            }
        }
    }

    private func performHeavyCalculation() async -> [RT60Result] {
        // Heavy DSP work
    }
}

// ❌ BAD - Blocking main thread
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published var results: [RT60Result]?

    func calculateRT60() {
        // ❌ Blocks UI!
        self.results = performHeavyCalculation()
    }
}
```

---

## 5. Audio & DSP

### 5.1 Audio Session Configuration

```swift
// ✅ GOOD - Proper audio session setup
func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()

    try session.setCategory(
        .record,
        mode: .measurement,
        options: []
    )

    try session.setPreferredSampleRate(48000)
    try session.setPreferredIOBufferDuration(0.005)  // 5ms latency

    try session.setActive(true)
}

// Handle interruptions
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: nil
) { notification in
    handleInterruption(notification)
}
```

### 5.2 FFT Best Practices

```swift
// ✅ GOOD - Efficient FFT with vDSP
import Accelerate

final class FFTProcessor {
    private let fftSetup: vDSP_DFT_Setup
    private let log2n: vDSP_Length

    init(size: Int) {
        self.log2n = vDSP_Length(log2(Double(size)))
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(size),
            .FORWARD
        )!
    }

    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }

    func transform(_ input: [Float]) -> DSPSplitComplex {
        var real = [Float](input)
        var imag = [Float](repeating: 0, count: input.count)

        var splitComplex = DSPSplitComplex(
            realp: &real,
            imagp: &imag
        )

        vDSP_DFT_Execute(fftSetup, real, imag, &splitComplex.realp, &splitComplex.imagp)

        return splitComplex
    }
}
```

### 5.3 Frequency Band Filtering

```swift
// ✅ GOOD - Bandpass Filter
final class BandpassFilter {
    private let lowFreq: Double
    private let highFreq: Double
    private let sampleRate: Double

    init(lowFreq: Double, highFreq: Double, sampleRate: Double) {
        self.lowFreq = lowFreq
        self.highFreq = highFreq
        self.sampleRate = sampleRate
    }

    func apply(to signal: [Float]) -> [Float] {
        // Butterworth bandpass filter implementation
        // Using vDSP for coefficient calculation and filtering

        let order = 4
        let coefficients = calculateCoefficients(order: order)

        var output = [Float](repeating: 0, count: signal.count)

        vDSP_deq22(
            signal,
            1,
            coefficients.a,
            coefficients.b,
            &output,
            1,
            vDSP_Length(signal.count)
        )

        return output
    }

    private func calculateCoefficients(order: Int) -> (a: [Double], b: [Double]) {
        // Butterworth coefficient calculation
        // ...
        return (a: [], b: [])
    }
}
```

---

## 6. Sicherheit & Privacy

### 6.1 Permission Handling

```swift
// ✅ GOOD - Graceful permission handling
@MainActor
final class PermissionManager: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .notDetermined

    func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            microphoneStatus = granted ? .authorized : .denied
            return granted

        case .granted:
            microphoneStatus = .authorized
            return true

        case .denied:
            microphoneStatus = .denied
            return false

        @unknown default:
            return false
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
}
```

### 6.2 Data Encryption

```swift
// ✅ GOOD - Sensitive data encryption
import CryptoKit

final class SecureStorage {

    func encrypt(data: Data) throws -> Data {
        let key = getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(data: Data) throws -> Data {
        let key = getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func getOrCreateKey() -> SymmetricKey {
        // Keychain storage
        if let keyData = loadFromKeychain() {
            return SymmetricKey(data: keyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        saveToKeychain(newKey.withUnsafeBytes { Data($0) })
        return newKey
    }

    private func loadFromKeychain() -> Data? {
        // Keychain query
    }

    private func saveToKeychain(_ data: Data) {
        // Keychain save
    }
}
```

### 6.3 Input Validation

```swift
// ✅ GOOD - Validate all inputs
func processAudioSample(_ sample: AudioSample) throws {
    // Validate sample rate
    guard sample.sampleRate >= 8000 && sample.sampleRate <= 192000 else {
        throw AudioError.invalidSampleRate
    }

    // Validate buffer size
    guard !sample.buffer.isEmpty && sample.buffer.count <= 10_000_000 else {
        throw AudioError.invalidBufferSize
    }

    // Validate duration
    guard sample.duration > 0 && sample.duration <= 3600 else {
        throw AudioError.invalidDuration
    }

    // Validate channels
    guard sample.channelCount > 0 && sample.channelCount <= 2 else {
        throw AudioError.invalidChannelCount
    }

    // Process validated input
}
```

---

## 7. Git & Version Control

### 7.1 Commit Messages

```bash
# ✅ GOOD - Conventional Commits
feat: Add RT60 calculation for 125 Hz frequency band
fix: Resolve audio recording permission crash on iOS 26
docs: Update architecture documentation with DSP details
test: Add unit tests for Schroeder integration method
refactor: Extract FFT processing into separate service
perf: Optimize frequency band filtering using vDSP
style: Apply SwiftLint formatting rules
chore: Update Xcode project settings

# ❌ BAD
Fixed stuff
WIP
asdfasdf
Update code
```

### 7.2 Branch Naming

```bash
# ✅ GOOD
feature/rt60-calculation
fix/audio-session-crash
refactor/mvvm-architecture
docs/setup-guide
test/integration-tests

# ❌ BAD
my-branch
test
fix
new-stuff
```

### 7.3 Pull Request Best Practices

**PR Template:**

```markdown
## Beschreibung
Kurze Beschreibung der Änderungen

## Typ der Änderung
- [ ] Bug Fix
- [ ] Neues Feature
- [ ] Breaking Change
- [ ] Dokumentation
- [ ] Refactoring

## Checklist
- [ ] Code folgt SwiftLint Rules
- [ ] Tests hinzugefügt/aktualisiert
- [ ] Dokumentation aktualisiert
- [ ] Alle Tests bestehen
- [ ] Code Review durchgeführt

## Screenshots (falls UI-Änderungen)
[Screenshots hier einfügen]

## Getestete Umgebung
- iOS Version: 26.0
- Device: iPhone 15 Pro Simulator
- Xcode: 26.0.1
```

---

## 8. Code Review

### 8.1 Code Review Checklist

**Funktionalität:**
- [ ] Code erfüllt die Anforderungen
- [ ] Keine offensichtlichen Bugs
- [ ] Edge Cases behandelt
- [ ] Error Handling implementiert

**Code-Qualität:**
- [ ] SOLID Principles befolgt
- [ ] DRY (Don't Repeat Yourself)
- [ ] Lesbar und wartbar
- [ ] Konsistenter Stil

**Testing:**
- [ ] Unit Tests vorhanden
- [ ] Tests bestehen
- [ ] Coverage > 80%
- [ ] Edge Cases getestet

**Performance:**
- [ ] Keine unnötigen Berechnungen
- [ ] Memory Leaks vermieden
- [ ] Async/Await korrekt verwendet
- [ ] UI bleibt responsive

**Sicherheit:**
- [ ] Input Validation
- [ ] Keine sensiblen Daten geloggt
- [ ] Permissions korrekt behandelt
- [ ] Keine Hard-coded Credentials

### 8.2 Code Review Kommentare

```swift
// ✅ GOOD - Konstruktive Kommentare
// 💡 Suggestion: Consider using vDSP for this operation for better performance
// ⚠️ Warning: This could cause a memory leak if not handled properly
// ✅ Approved: Clean implementation, follows MVVM pattern
// ❓ Question: Should we add error handling for this edge case?

// ❌ BAD - Unproduktive Kommentare
// This is wrong
// I don't like this
// Bad code
// Fix this
```

---

## 9. Accessibility

### 9.1 VoiceOver Support

```swift
// ✅ GOOD - Accessibility Labels
Button(action: startRecording) {
    Image(systemName: "record.circle")
}
.accessibilityLabel("Aufnahme starten")
.accessibilityHint("Startet die RT60-Messung")

Text("\(rt60Value, specifier: "%.2f") Sekunden")
    .accessibilityLabel("Nachhallzeit: \(rt60Value, specifier: "%.2f") Sekunden")

// ❌ BAD - Keine Accessibility
Button(action: startRecording) {
    Image(systemName: "record.circle")
}
```

### 9.2 Dynamic Type Support

```swift
// ✅ GOOD - Skalierbare Fonts
Text("RT60 Messung")
    .font(.title)  // System font, scales automatically

// ✅ GOOD - Custom Font mit Scaling
Text("RT60 Messung")
    .font(.custom("HelveticaNeue-Bold", size: 24, relativeTo: .title))

// ❌ BAD - Fixed Size
Text("RT60 Messung")
    .font(.system(size: 24))  // Doesn't scale
```

### 9.3 Color Contrast

```swift
// ✅ GOOD - High Contrast
Color.accentColor  // System accent, adapts to user preference

// ✅ GOOD - Semantic Colors
Color.primary
Color.secondary
Color.red  // For errors

// ❌ BAD - Custom colors without high contrast support
Color(red: 0.9, green: 0.9, blue: 0.9)  // Low contrast
```

---

## 10. Dokumentation

### 10.1 Code Documentation (DocC)

```swift
// ✅ GOOD - Comprehensive DocC
/// Calculates the RT60 reverberation time from an audio sample.
///
/// This function uses the Schroeder integration method to determine
/// the time it takes for sound to decay by 60 dB.
///
/// - Parameter sample: The audio sample to analyze
/// - Returns: The calculated RT60 result including value, confidence, and decay curve
/// - Throws: `RT60Error.invalidInput` if the sample is invalid
///          `RT60Error.calculationFailed` if the calculation fails
///
/// ## Example
/// ```swift
/// let sample = AudioSample(buffer: recordedData, sampleRate: 48000, duration: 5.0, channelCount: 1)
/// let result = try await calculator.calculate(from: sample)
/// print("RT60: \(result.value) seconds")
/// ```
///
/// - Note: The sample should have a sufficient signal-to-noise ratio for accurate results.
/// - Warning: Very short samples (<1 second) may produce unreliable results.
func calculate(from sample: AudioSample) async throws -> RT60Result {
    // Implementation
}

// ❌ BAD - Keine oder minimale Dokumentation
func calculate(from sample: AudioSample) async throws -> RT60Result {
    // Implementation
}
```

### 10.2 README Updates

**Regel:** README immer aktuell halten

- ✅ Neue Features dokumentieren
- ✅ Setup-Schritte aktualisieren
- ✅ Dependencies auflisten
- ✅ Screenshots bei UI-Änderungen

### 10.3 Architecture Decision Records (ADRs)

```markdown
# ADR 001: Use Schroeder Integration Method for RT60 Calculation

## Status
Accepted

## Context
We need to choose an algorithm for RT60 calculation. Options:
1. Linear regression on decay curve
2. Schroeder integration method
3. ML-based estimation

## Decision
Use Schroeder integration method.

## Consequences
**Positive:**
- Industry standard (ISO 3382)
- Reliable and well-tested
- Good accuracy

**Negative:**
- Requires impulse response
- Computational overhead

## Alternatives Considered
- Linear regression: Less accurate
- ML: Requires training data
```

---

## 11. Checklists

### 11.1 Pre-Commit Checklist

- [ ] Code kompiliert ohne Warnings
- [ ] SwiftLint Regeln befolgt
- [ ] Alle Tests bestehen
- [ ] Keine Debug-Prints oder Kommentare
- [ ] Keine auskommentierten Code-Blöcke
- [ ] Dokumentation aktualisiert
- [ ] Git Commit Message korrekt formatiert

### 11.2 Pre-Release Checklist

- [ ] Alle Features getestet (Device + Simulator)
- [ ] Performance Tests durchgeführt
- [ ] Memory Leaks geprüft (Instruments)
- [ ] Crash Analytics geprüft
- [ ] App Store Screenshots aktualisiert
- [ ] Release Notes geschrieben
- [ ] Version Number aktualisiert
- [ ] Build Number inkrementiert
- [ ] Code Signing konfiguriert
- [ ] TestFlight Beta Test durchgeführt

---

## 12. Nützliche Tools

### 12.1 Entwicklung

| Tool | Zweck | Link |
|------|-------|------|
| **SwiftLint** | Code Quality | [GitHub](https://github.com/realm/SwiftLint) |
| **Periphery** | Unused Code Detection | [GitHub](https://github.com/peripheryapp/periphery) |
| **SwiftFormat** | Code Formatting | [GitHub](https://github.com/nicklockwood/SwiftFormat) |

### 12.2 Performance

| Tool | Zweck |
|------|-------|
| **Instruments** | Performance Profiling |
| **Xcode Memory Graph** | Memory Leak Detection |
| **Time Profiler** | CPU Usage Analysis |
| **Allocations** | Memory Allocation Tracking |

### 12.3 CI/CD

| Tool | Zweck |
|------|-------|
| **Fastlane** | Automation |
| **GitHub Actions** | CI/CD |
| **xcpretty** | Test Output Formatting |

---

## 13. Ressourcen

### Offizielle Dokumentation
- [Swift.org](https://swift.org/)
- [Apple Developer](https://developer.apple.com/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)

### Best Practices
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Ray Wenderlich](https://www.raywenderlich.com/)
- [Point-Free](https://www.pointfree.co/)

### Audio & DSP
- [Accelerate Framework](https://developer.apple.com/documentation/accelerate/)
- [AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [DSP Guide](https://www.dspguide.com/)

---

**Version:** 1.0
**Last Updated:** 23.11.2025
**Maintainer:** Akusti-Scan-App-RT60 Team
