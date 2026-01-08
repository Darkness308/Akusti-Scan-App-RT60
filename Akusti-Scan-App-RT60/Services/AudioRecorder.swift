//
//  AudioRecorder.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import AVFoundation
import Combine

/// Status des Audio-Recorders
enum RecorderState {
    case idle
    case requestingPermission
    case permissionDenied
    case preparing
    case recording
    case processing
    case error(String)
}

/// Audio-Recorder für RT60-Messungen
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: RecorderState = .idle
    @Published private(set) var currentLevel: Float = -160
    @Published private(set) var peakLevel: Float = -160
    @Published private(set) var recordedSamples: [Float] = []
    @Published private(set) var isImpulseDetected: Bool = false

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var sampleRate: Double = 44100
    private var bufferSize: AVAudioFrameCount = 4096

    private var allSamples: [Float] = []
    private var impulseThreshold: Float = 0.5
    private var impulseDetectionEnabled: Bool = true
    private var recordingStartTime: Date?
    private var maxRecordingDuration: TimeInterval = 10.0

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Überprüft und fordert Mikrofonberechtigung an
    func requestPermission() async -> Bool {
        state = .requestingPermission

        // iOS 17+ verwendet AVAudioApplication, ältere Versionen AVAudioSession
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        if granted {
                            self.state = .idle
                        } else {
                            self.state = .permissionDenied
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        if granted {
                            self.state = .idle
                        } else {
                            self.state = .permissionDenied
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    /// Startet die Audioaufnahme
    func startRecording() async throws {
        guard state != .recording else { return }

        state = .preparing

        // Audio-Session konfigurieren
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        // Audio-Engine aufsetzen
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioRecorderError.engineInitializationFailed
        }

        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw AudioRecorderError.inputNodeNotAvailable
        }

        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        // Reset
        allSamples = []
        peakLevel = -160
        isImpulseDetected = false
        recordingStartTime = Date()

        // Tap installieren
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                self?.processAudioBuffer(buffer)
            }
        }

        // Engine starten
        try engine.start()
        state = .recording
    }

    /// Stoppt die Aufnahme
    func stopRecording() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        recordedSamples = allSamples
        state = .idle
    }

    /// Setzt den Recorder zurück
    func reset() {
        stopRecording()
        allSamples = []
        recordedSamples = []
        currentLevel = -160
        peakLevel = -160
        isImpulseDetected = false
    }

    /// Gibt aufgenommene Audio-Samples zurück
    func getAudioSample() -> AudioSample {
        return AudioSample(
            samples: recordedSamples,
            sampleRate: sampleRate,
            channelCount: 1,
            duration: Double(recordedSamples.count) / sampleRate
        )
    }

    // MARK: - Private Methods

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Samples speichern
        allSamples.append(contentsOf: samples)

        // Level berechnen
        let rms = calculateRMS(samples)
        let rmsDB = 20 * log10(max(rms, 1e-10))
        currentLevel = rmsDB

        // Peak-Level aktualisieren
        let peak = samples.map { abs($0) }.max() ?? 0
        let peakDB = 20 * log10(max(peak, 1e-10))
        if peakDB > peakLevel {
            peakLevel = peakDB
        }

        // Impuls-Erkennung
        if impulseDetectionEnabled && peak > impulseThreshold && !isImpulseDetected {
            isImpulseDetected = true
        }

        // Automatisches Stoppen nach maximaler Dauer
        if let startTime = recordingStartTime,
           Date().timeIntervalSince(startTime) > maxRecordingDuration {
            stopRecording()
        }
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case engineInitializationFailed
    case inputNodeNotAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .engineInitializationFailed:
            return "Audio-Engine konnte nicht initialisiert werden"
        case .inputNodeNotAvailable:
            return "Mikrofon-Eingang nicht verfügbar"
        case .permissionDenied:
            return "Mikrofonzugriff wurde verweigert"
        }
    }
}
