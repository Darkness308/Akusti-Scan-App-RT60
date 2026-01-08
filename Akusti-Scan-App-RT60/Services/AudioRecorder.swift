//
//  AudioRecorder.swift
//  Akusti-Scan-App-RT60
//
//  Audio recording service for RT60 measurements
//

import AVFoundation
import Accelerate

/// Errors that can occur during audio operations
enum AudioError: Error, LocalizedError {
    case microphoneAccessDenied
    case microphoneAccessRestricted
    case recordingFailed(String)
    case engineStartFailed(String)
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Mikrofonzugriff wurde verweigert. Bitte aktivieren Sie den Zugriff in den Einstellungen."
        case .microphoneAccessRestricted:
            return "Mikrofonzugriff ist eingeschränkt."
        case .recordingFailed(let message):
            return "Aufnahme fehlgeschlagen: \(message)"
        case .engineStartFailed(let message):
            return "Audio-Engine konnte nicht gestartet werden: \(message)"
        case .noAudioData:
            return "Keine Audiodaten verfügbar."
        }
    }
}

/// Service for recording audio and capturing samples for RT60 analysis
@MainActor
@Observable
final class AudioRecorder {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []

    private(set) var isRecording = false
    private(set) var currentLevel: Float = 0
    private(set) var error: AudioError?

    /// Sample rate for audio capture (44.1 kHz standard)
    let sampleRate: Double = 44100

    /// Buffer size for FFT analysis
    let bufferSize: AVAudioFrameCount = 4096

    // MARK: - Initialization

    init() {}

    // MARK: - Permission Handling

    /// Request microphone permission
    func requestPermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission

        switch status {
        case .granted:
            return true
        case .denied:
            error = .microphoneAccessDenied
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Recording

    /// Start recording audio
    func startRecording() async throws {
        guard await requestPermission() else {
            throw AudioError.microphoneAccessDenied
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Clear previous buffer
        audioBuffer.removeAll()

        // Install tap on input node to capture audio
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Get audio samples
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            // Append samples to buffer
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

            Task { @MainActor in
                self.audioBuffer.append(contentsOf: samples)
                self.currentLevel = self.calculateRMSLevel(samples)
            }
        }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement)
        try session.setActive(true)

        // Start engine
        do {
            try engine.start()
            audioEngine = engine
            isRecording = true
        } catch {
            throw AudioError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Stop recording and return captured samples
    func stopRecording() -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        return audioBuffer
    }

    // MARK: - Audio Analysis

    /// Calculate RMS level of audio samples
    private func calculateRMSLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Convert to decibels
        let db = 20 * log10(rms)
        return max(-60, min(0, db)) // Clamp between -60 dB and 0 dB
    }
}
