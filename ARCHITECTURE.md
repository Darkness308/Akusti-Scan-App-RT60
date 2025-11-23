# Architektur-Design - Akusti-Scan-App-RT60

## 📐 Architektur-Übersicht

Dieses Dokument beschreibt die empfohlene Software-Architektur für die Akusti-Scan-App mit Fokus auf RT60-Messungen.

---

## 1. Architektur-Pattern: MVVM + Clean Architecture

### 1.1 Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │    Views     │→ │  ViewModels  │→ │ UI State & Actions  │   │
│  │  (SwiftUI)   │  │ (Observable) │  │                     │   │
│  └──────────────┘  └──────────────┘  └─────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                          Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │   Entities   │  │  Use Cases   │  │    Repositories     │   │
│  │  (Models)    │  │(Business Logic)│ │   (Protocols)       │   │
│  └──────────────┘  └──────────────┘  └─────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                           Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │ Repositories │  │   Services   │  │     Storage         │   │
│  │(Impl)        │  │ (Audio, DSP) │  │ (CoreData, Files)   │   │
│  └──────────────┘  └──────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Dependency Flow

**Regel:** Abhängigkeiten zeigen immer nach innen (Domain ist unabhängig)

```
Presentation → Domain ← Data
```

- **Presentation** kennt **Domain**
- **Data** kennt **Domain**
- **Domain** kennt niemanden (reine Business Logic)

---

## 2. Detaillierte Komponenten-Architektur

### 2.1 Projekt-Struktur

```
Akusti-Scan-App-RT60/
│
├── App/
│   ├── Akusti_Scan_App_RT60App.swift
│   ├── AppDelegate.swift (wenn benötigt)
│   └── DependencyContainer.swift
│
├── Features/
│   ├── Measurement/
│   │   ├── Views/
│   │   │   ├── MeasurementView.swift
│   │   │   ├── RecordingControlsView.swift
│   │   │   └── RT60ResultView.swift
│   │   ├── ViewModels/
│   │   │   └── MeasurementViewModel.swift
│   │   └── Components/
│   │       ├── WaveformView.swift
│   │       ├── FrequencyBandView.swift
│   │       └── RecordingIndicator.swift
│   │
│   ├── History/
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift
│   │   │   └── MeasurementDetailView.swift
│   │   └── ViewModels/
│   │       └── HistoryViewModel.swift
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   │   └── SettingsView.swift
│   │   └── ViewModels/
│   │       └── SettingsViewModel.swift
│   │
│   └── Onboarding/
│       ├── Views/
│       │   └── OnboardingView.swift
│       └── ViewModels/
│           └── OnboardingViewModel.swift
│
├── Domain/
│   ├── Entities/
│   │   ├── Measurement.swift
│   │   ├── RT60Result.swift
│   │   ├── FrequencyBand.swift
│   │   └── AudioSample.swift
│   │
│   ├── UseCases/
│   │   ├── RecordAudioUseCase.swift
│   │   ├── CalculateRT60UseCase.swift
│   │   ├── SaveMeasurementUseCase.swift
│   │   └── ExportMeasurementUseCase.swift
│   │
│   └── Repositories/
│       ├── AudioRepositoryProtocol.swift
│       ├── MeasurementRepositoryProtocol.swift
│       └── SettingsRepositoryProtocol.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── AudioRepository.swift
│   │   ├── MeasurementRepository.swift
│   │   └── SettingsRepository.swift
│   │
│   ├── Services/
│   │   ├── Audio/
│   │   │   ├── AudioRecorder.swift
│   │   │   ├── AudioPlayer.swift
│   │   │   └── AudioSession.swift
│   │   ├── DSP/
│   │   │   ├── FFTProcessor.swift
│   │   │   ├── RT60Calculator.swift
│   │   │   └── FilterBank.swift
│   │   └── Permission/
│   │       └── PermissionManager.swift
│   │
│   └── Storage/
│       ├── CoreData/
│       │   ├── PersistenceController.swift
│       │   ├── MeasurementEntity+CoreData.swift
│       │   └── AkustiScan.xcdatamodeld
│       └── FileSystem/
│           ├── AudioFileManager.swift
│           └── ExportManager.swift
│
├── Core/
│   ├── Extensions/
│   │   ├── Array+DSP.swift
│   │   ├── Date+Formatting.swift
│   │   └── Double+Audio.swift
│   │
│   ├── Utilities/
│   │   ├── Logger.swift
│   │   ├── Constants.swift
│   │   └── Helpers.swift
│   │
│   └── UI/
│       ├── Theme/
│       │   ├── Colors.swift
│       │   ├── Typography.swift
│       │   └── Spacing.swift
│       └── Components/
│           ├── LoadingView.swift
│           ├── ErrorView.swift
│           └── EmptyStateView.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   ├── Localizable.xcstrings
│   └── Info.plist
│
└── Tests/
    ├── UnitTests/
    │   ├── Domain/
    │   ├── Data/
    │   └── Mocks/
    └── UITests/
        └── Flows/
```

---

## 3. Kern-Komponenten Design

### 3.1 Domain Layer

#### 3.1.1 Entities (Models)

```swift
// Domain/Entities/Measurement.swift
struct Measurement: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let rt60Results: [FrequencyBand: RT60Result]
    let audioFileURL: URL?
    let location: Location?
    let notes: String?
    let roomType: RoomType?

    var averageRT60: TimeInterval {
        let values = rt60Results.values.map { $0.value }
        return values.reduce(0, +) / Double(values.count)
    }
}

// Domain/Entities/RT60Result.swift
struct RT60Result: Codable {
    let value: TimeInterval // in seconds
    let confidence: Double // 0.0 - 1.0
    let decayCurve: [DataPoint]

    struct DataPoint: Codable {
        let time: TimeInterval
        let amplitude: Double // in dB
    }
}

// Domain/Entities/FrequencyBand.swift
enum FrequencyBand: String, CaseIterable, Codable {
    case hz125 = "125 Hz"
    case hz250 = "250 Hz"
    case hz500 = "500 Hz"
    case hz1000 = "1000 Hz"
    case hz2000 = "2000 Hz"
    case hz4000 = "4000 Hz"
    case hz8000 = "8000 Hz"

    var centerFrequency: Double {
        switch self {
        case .hz125: return 125
        case .hz250: return 250
        case .hz500: return 500
        case .hz1000: return 1000
        case .hz2000: return 2000
        case .hz4000: return 4000
        case .hz8000: return 8000
        }
    }

    var lowerBound: Double {
        centerFrequency / sqrt(2)
    }

    var upperBound: Double {
        centerFrequency * sqrt(2)
    }
}

// Domain/Entities/AudioSample.swift
struct AudioSample {
    let buffer: [Float]
    let sampleRate: Double
    let duration: TimeInterval
    let channelCount: Int
}
```

#### 3.1.2 Use Cases

```swift
// Domain/UseCases/RecordAudioUseCase.swift
protocol RecordAudioUseCase {
    func startRecording() async throws
    func stopRecording() async throws -> AudioSample
    var isRecording: Bool { get }
    var recordingDuration: TimeInterval { get }
}

// Domain/UseCases/CalculateRT60UseCase.swift
protocol CalculateRT60UseCase {
    func calculate(from sample: AudioSample) async throws -> [FrequencyBand: RT60Result]
}

// Domain/UseCases/SaveMeasurementUseCase.swift
protocol SaveMeasurementUseCase {
    func save(_ measurement: Measurement) async throws
}

// Domain/UseCases/ExportMeasurementUseCase.swift
protocol ExportMeasurementUseCase {
    func export(_ measurement: Measurement, format: ExportFormat) async throws -> URL
}

enum ExportFormat {
    case csv
    case json
    case pdf
}
```

#### 3.1.3 Repository Protocols

```swift
// Domain/Repositories/AudioRepositoryProtocol.swift
protocol AudioRepositoryProtocol {
    func requestMicrophonePermission() async -> Bool
    func checkMicrophonePermission() -> Bool
    func startRecording() async throws
    func stopRecording() async throws -> AudioSample
    func playback(_ sample: AudioSample) async throws
}

// Domain/Repositories/MeasurementRepositoryProtocol.swift
protocol MeasurementRepositoryProtocol {
    func save(_ measurement: Measurement) async throws
    func fetchAll() async throws -> [Measurement]
    func fetch(by id: UUID) async throws -> Measurement?
    func delete(_ measurement: Measurement) async throws
}
```

---

### 3.2 Data Layer

#### 3.2.1 Audio Service

```swift
// Data/Services/Audio/AudioRecorder.swift
import AVFoundation

@MainActor
final class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var recordedBuffer: AVAudioPCMBuffer?

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() throws -> AudioSample {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isRecording = false

        guard let buffer = recordedBuffer else {
            throw AudioError.noRecordedData
        }

        return AudioSample(
            buffer: Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))),
            sampleRate: buffer.format.sampleRate,
            duration: Double(buffer.frameLength) / buffer.format.sampleRate,
            channelCount: Int(buffer.format.channelCount)
        )
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Append to recorded buffer
    }
}
```

#### 3.2.2 RT60 Calculator

```swift
// Data/Services/DSP/RT60Calculator.swift
import Accelerate

final class RT60Calculator {

    func calculate(from sample: AudioSample) async throws -> [FrequencyBand: RT60Result] {
        var results: [FrequencyBand: RT60Result] = [:]

        for band in FrequencyBand.allCases {
            let filteredSignal = try await filterSignal(sample, band: band)
            let impulseResponse = try await extractImpulseResponse(filteredSignal)
            let rt60 = try calculateRT60(from: impulseResponse)

            results[band] = rt60
        }

        return results
    }

    private func filterSignal(_ sample: AudioSample, band: FrequencyBand) async throws -> [Float] {
        // Bandpass Filter implementation
        // Using vDSP for efficiency

        let filter = BandpassFilter(
            lowFreq: band.lowerBound,
            highFreq: band.upperBound,
            sampleRate: sample.sampleRate
        )

        return filter.apply(to: sample.buffer)
    }

    private func extractImpulseResponse(_ signal: [Float]) async throws -> [Float] {
        // Impulse response extraction
        // Can use:
        // - Direct measurement (if impulse is provided)
        // - Swept-sine technique
        // - MLS (Maximum Length Sequence)

        return signal
    }

    private func calculateRT60(from impulseResponse: [Float]) throws -> RT60Result {
        // Schroeder Integration Method

        // 1. Square the impulse response
        var squared = [Float](repeating: 0, count: impulseResponse.count)
        vDSP_vsq(impulseResponse, 1, &squared, 1, vDSP_Length(impulseResponse.count))

        // 2. Reverse integrate (backward cumsum)
        let integrated = backwardCumulativeSum(squared)

        // 3. Convert to dB
        var dB = [Float](repeating: 0, count: integrated.count)
        var divisor: Float = 1.0
        vDSP_vdbcon(integrated, 1, &divisor, &dB, 1, vDSP_Length(integrated.count), 1)

        // 4. Linear regression on -5dB to -35dB range
        let (startIdx, endIdx) = findDecayRange(dB: dB)
        let slope = linearRegression(dB: dB, startIdx: startIdx, endIdx: endIdx)

        // 5. Extrapolate to -60dB
        let rt60Value = 60.0 / abs(slope)

        // 6. Calculate confidence based on linearity
        let confidence = calculateConfidence(dB: dB, startIdx: startIdx, endIdx: endIdx, slope: slope)

        // 7. Create decay curve data points
        let decayCurve = createDecayCurve(dB: dB, sampleRate: 48000) // TODO: use actual sample rate

        return RT60Result(
            value: TimeInterval(rt60Value),
            confidence: confidence,
            decayCurve: decayCurve
        )
    }

    private func backwardCumulativeSum(_ array: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: array.count)
        var sum: Float = 0

        for i in (0..<array.count).reversed() {
            sum += array[i]
            result[i] = sum
        }

        return result
    }

    private func findDecayRange(dB: [Float]) -> (Int, Int) {
        // Find indices where dB is between -5 and -35
        let maxdB = dB.max() ?? 0

        var startIdx = 0
        var endIdx = dB.count - 1

        for (i, value) in dB.enumerated() {
            if value < maxdB - 5 && startIdx == 0 {
                startIdx = i
            }
            if value < maxdB - 35 {
                endIdx = i
                break
            }
        }

        return (startIdx, endIdx)
    }

    private func linearRegression(dB: [Float], startIdx: Int, endIdx: Int) -> Float {
        let n = Float(endIdx - startIdx)
        let x = Array(0..<(endIdx - startIdx)).map { Float($0) }
        let y = Array(dB[startIdx..<endIdx])

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)

        return slope
    }

    private func calculateConfidence(dB: [Float], startIdx: Int, endIdx: Int, slope: Float) -> Double {
        // Calculate R² (coefficient of determination)
        let y = Array(dB[startIdx..<endIdx])
        let n = y.count

        let meanY = y.reduce(0, +) / Float(n)

        var ssRes: Float = 0
        var ssTot: Float = 0

        for (i, yi) in y.enumerated() {
            let yPred = slope * Float(i)
            ssRes += pow(yi - yPred, 2)
            ssTot += pow(yi - meanY, 2)
        }

        let rSquared = 1 - (ssRes / ssTot)

        return max(0, min(1, Double(rSquared)))
    }

    private func createDecayCurve(dB: [Float], sampleRate: Double) -> [RT60Result.DataPoint] {
        dB.enumerated().compactMap { index, amplitude in
            RT60Result.DataPoint(
                time: Double(index) / sampleRate,
                amplitude: Double(amplitude)
            )
        }
    }
}
```

---

### 3.3 Presentation Layer

#### 3.3.1 MeasurementViewModel

```swift
// Features/Measurement/ViewModels/MeasurementViewModel.swift
import SwiftUI
import Combine

@MainActor
final class MeasurementViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var rt60Results: [FrequencyBand: RT60Result]?
    @Published var error: MeasurementError?
    @Published var state: MeasurementState = .idle

    // MARK: - Dependencies
    private let recordAudioUseCase: RecordAudioUseCase
    private let calculateRT60UseCase: CalculateRT60UseCase
    private let saveMeasurementUseCase: SaveMeasurementUseCase

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?

    // MARK: - State
    enum MeasurementState {
        case idle
        case recording
        case processing
        case completed
        case error
    }

    // MARK: - Init
    init(
        recordAudioUseCase: RecordAudioUseCase,
        calculateRT60UseCase: CalculateRT60UseCase,
        saveMeasurementUseCase: SaveMeasurementUseCase
    ) {
        self.recordAudioUseCase = recordAudioUseCase
        self.calculateRT60UseCase = calculateRT60UseCase
        self.saveMeasurementUseCase = saveMeasurementUseCase
    }

    // MARK: - Actions
    func startRecording() {
        Task {
            do {
                try await recordAudioUseCase.startRecording()
                state = .recording
                isRecording = true
                startTimer()
            } catch {
                self.error = .recordingFailed(error)
                state = .error
            }
        }
    }

    func stopRecording() {
        Task {
            do {
                stopTimer()
                isRecording = false

                let audioSample = try await recordAudioUseCase.stopRecording()

                state = .processing

                let results = try await calculateRT60UseCase.calculate(from: audioSample)
                rt60Results = results

                state = .completed
            } catch {
                self.error = .processingFailed(error)
                state = .error
            }
        }
    }

    func saveMeasurement(notes: String? = nil) {
        Task {
            guard let results = rt60Results else { return }

            let measurement = Measurement(
                id: UUID(),
                timestamp: Date(),
                rt60Results: results,
                audioFileURL: nil,
                location: nil,
                notes: notes,
                roomType: nil
            )

            do {
                try await saveMeasurementUseCase.save(measurement)
            } catch {
                self.error = .saveFailed(error)
            }
        }
    }

    // MARK: - Private
    private func startTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - Error
enum MeasurementError: LocalizedError {
    case recordingFailed(Error)
    case processingFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .recordingFailed(let error):
            return "Aufnahme fehlgeschlagen: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Verarbeitung fehlgeschlagen: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
```

#### 3.3.2 MeasurementView

```swift
// Features/Measurement/Views/MeasurementView.swift
import SwiftUI

struct MeasurementView: View {
    @StateObject private var viewModel: MeasurementViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerView

            // Recording Controls
            if viewModel.state != .completed {
                recordingControlsView
            }

            // Results
            if let results = viewModel.rt60Results {
                RT60ResultView(results: results)
            }

            Spacer()
        }
        .padding()
        .alert(error: $viewModel.error)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("RT60 Messung")
                .font(.title)
                .fontWeight(.bold)

            if viewModel.isRecording {
                Text(formatDuration(viewModel.recordingDuration))
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
    }

    private var recordingControlsView: some View {
        VStack(spacing: 16) {
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title)
                    Text(viewModel.isRecording ? "Stop" : "Aufnahme starten")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isRecording ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if viewModel.state == .processing {
                ProgressView("Berechne RT60...")
            }
        }
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}
```

---

## 4. Dependency Injection

### 4.1 Dependency Container

```swift
// App/DependencyContainer.swift
final class DependencyContainer {

    // MARK: - Shared Instance
    static let shared = DependencyContainer()

    // MARK: - Repositories
    lazy var audioRepository: AudioRepositoryProtocol = AudioRepository()
    lazy var measurementRepository: MeasurementRepositoryProtocol = MeasurementRepository()

    // MARK: - Services
    lazy var audioRecorder = AudioRecorder()
    lazy var rt60Calculator = RT60Calculator()
    lazy var permissionManager = PermissionManager()

    // MARK: - Use Cases
    lazy var recordAudioUseCase: RecordAudioUseCase = RecordAudioUseCaseImpl(
        audioRepository: audioRepository
    )

    lazy var calculateRT60UseCase: CalculateRT60UseCase = CalculateRT60UseCaseImpl(
        calculator: rt60Calculator
    )

    lazy var saveMeasurementUseCase: SaveMeasurementUseCase = SaveMeasurementUseCaseImpl(
        measurementRepository: measurementRepository
    )

    // MARK: - ViewModels
    func makeMeasurementViewModel() -> MeasurementViewModel {
        MeasurementViewModel(
            recordAudioUseCase: recordAudioUseCase,
            calculateRT60UseCase: calculateRT60UseCase,
            saveMeasurementUseCase: saveMeasurementUseCase
        )
    }
}
```

### 4.2 App Integration

```swift
// App/Akusti_Scan_App_RT60App.swift
@main
struct Akusti_Scan_App_RT60App: App {

    let container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.audioRecorder)
                .environmentObject(container.permissionManager)
        }
    }
}
```

---

## 5. Data Flow

### 5.1 Recording Flow

```
User Tap "Record"
       │
       ↓
  ViewModel.startRecording()
       │
       ↓
  RecordAudioUseCase
       │
       ↓
  AudioRepository
       │
       ↓
  AudioRecorder (AVAudioEngine)
       │
       ↓
  [Recording in progress]
       │
User Tap "Stop" ↓
       ↓
  ViewModel.stopRecording()
       │
       ↓
  AudioRecorder returns AudioSample
       │
       ↓
  CalculateRT60UseCase
       │
       ↓
  RT60Calculator (DSP processing)
       │
       ↓
  Returns [FrequencyBand: RT60Result]
       │
       ↓
  ViewModel updates UI
       │
       ↓
  Display results
```

### 5.2 Data Persistence Flow

```
RT60 Results
       │
       ↓
  ViewModel.saveMeasurement()
       │
       ↓
  SaveMeasurementUseCase
       │
       ↓
  MeasurementRepository
       │
       ├─→ CoreData (Metadata)
       │
       └─→ FileSystem (Audio Files)
```

---

## 6. Testing-Strategie

### 6.1 Unit Tests

**Domain Layer (100% Coverage Ziel):**
- ✅ RT60Calculator: Algorithmus-Tests
- ✅ Use Cases: Business Logic
- ✅ Entities: Model Validation

**Data Layer:**
- ✅ Repositories: CRUD Operations
- ✅ FFT Processor: DSP Correctness
- ✅ Audio File Manager

### 6.2 Integration Tests

- Audio Recording → Processing Pipeline
- CoreData Persistence
- File System Operations

### 6.3 UI Tests

- Recording Flow
- Permission Handling
- Results Display
- Export Functionality

---

## 7. Performance Optimierungen

### 7.1 Audio Processing

```swift
// Use Accelerate Framework
import Accelerate

// Parallel processing for frequency bands
await withTaskGroup(of: RT60Result.self) { group in
    for band in FrequencyBand.allCases {
        group.addTask {
            try await self.processFrequencyBand(band)
        }
    }

    for await result in group {
        results[result.band] = result
    }
}
```

### 7.2 Memory Management

```swift
// Process audio in chunks
func processLargeAudioFile(url: URL) async throws {
    let chunkSize = 4096

    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat

    while file.framePosition < file.length {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunkSize))!
        try file.read(into: buffer)

        // Process chunk
        processChunk(buffer)
    }
}
```

### 7.3 UI Responsiveness

```swift
// Offload heavy calculations
Task.detached {
    let results = try await calculateRT60(sample)

    await MainActor.run {
        self.results = results
    }
}
```

---

## 8. Erweiterbarkeit

### 8.1 Zukünftige Features

**Phase 2:**
- 🎯 Cloud Sync
- 🎯 Collaboration (Share Measurements)
- 🎯 Advanced Analytics

**Phase 3:**
- 🎯 Machine Learning (Room Classification)
- 🎯 Augmented Reality (Room Visualization)
- 🎯 Calibration Tools

### 8.2 Plugin Architecture

```swift
protocol MeasurementPlugin {
    var name: String { get }
    func process(measurement: Measurement) async throws -> ProcessedData
}

// Example: PDF Export Plugin
struct PDFExportPlugin: MeasurementPlugin {
    var name = "PDF Exporter"

    func process(measurement: Measurement) async throws -> ProcessedData {
        // Generate PDF
    }
}
```

---

## 9. Sicherheit & Privacy

### 9.1 Permission Management

```swift
final class PermissionManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .notDetermined

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
}
```

### 9.2 Data Encryption

```swift
// For sensitive data (if user credentials added later)
import CryptoKit

func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(data, using: key)
    return sealedBox.combined!
}
```

---

## 10. Monitoring & Logging

```swift
// Core/Utilities/Logger.swift
import OSLog

struct AppLogger {
    static let audio = Logger(subsystem: "com.msh.akustiscan", category: "Audio")
    static let rt60 = Logger(subsystem: "com.msh.akustiscan", category: "RT60")
    static let ui = Logger(subsystem: "com.msh.akustiscan", category: "UI")

    static func logError(_ error: Error, category: Logger) {
        category.error("Error: \(error.localizedDescription)")
    }
}

// Usage
AppLogger.audio.info("Recording started")
AppLogger.rt60.debug("Calculating RT60 for \(band.rawValue)")
```

---

## 11. Fazit

Diese Architektur bietet:

✅ **Skalierbarkeit** - Einfach erweiterbar
✅ **Testbarkeit** - Alle Komponenten testbar
✅ **Wartbarkeit** - Klare Verantwortlichkeiten
✅ **Performance** - Optimiert für Audio-Processing
✅ **Modularität** - Lose Kopplung
✅ **Clean Code** - SOLID Principles

---

**Version:** 1.0
**Last Updated:** 23.11.2025
**Status:** 📐 Design Complete - Ready for Implementation
