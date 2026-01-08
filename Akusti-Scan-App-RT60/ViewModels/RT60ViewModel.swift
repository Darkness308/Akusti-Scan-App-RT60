//
//  RT60ViewModel.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import SwiftUI
import Combine

/// Messmodus
enum MeasurementMode: String, CaseIterable {
    case impulse = "Impuls"
    case continuous = "Kontinuierlich"

    var description: String {
        switch self {
        case .impulse:
            return "Klatschen oder Ballon platzen lassen"
        case .continuous:
            return "Für Hintergrundanalyse"
        }
    }
}

/// Haupt-ViewModel für RT60-Messungen
@MainActor
final class RT60ViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var measurementState: MeasurementState = .idle
    @Published var currentLevel: Float = -60
    @Published var peakLevel: Float = -60
    @Published var latestMeasurement: RT60Measurement?
    @Published var measurementHistory: [RT60Measurement] = []
    @Published var bandMeasurements: [FrequencyBand: RT60Measurement] = [:]
    @Published var decayCurve: DecayCurve?
    @Published var selectedRoomType: RoomType = .livingRoom
    @Published var measurementMode: MeasurementMode = .impulse
    @Published var showBandAnalysis: Bool = false
    @Published var errorMessage: String?
    @Published var hasPermission: Bool = false

    // MARK: - Private Properties

    private let audioRecorder = AudioRecorder()
    private let rt60Calculator = RT60Calculator()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var acousticRating: RoomAcousticRating? {
        guard let measurement = latestMeasurement, measurement.isValid else { return nil }
        return RoomAcousticRating.fromRT60(measurement.rt60Value, roomType: selectedRoomType)
    }

    var formattedRT60: String {
        guard let measurement = latestMeasurement, measurement.isValid else { return "-- s" }
        return String(format: "%.2f s", measurement.rt60Value)
    }

    var optimalRangeText: String {
        let range = selectedRoomType.optimalRT60Range
        return String(format: "%.1f - %.1f s", range.lowerBound, range.upperBound)
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    /// Prüft und fordert Mikrofonberechtigung an
    func checkPermission() async {
        hasPermission = await audioRecorder.requestPermission()
        if !hasPermission {
            measurementState = .permissionDenied
        }
    }

    /// Startet eine Messung
    func startMeasurement() async {
        guard hasPermission else {
            await checkPermission()
            guard hasPermission else { return }
        }

        errorMessage = nil
        measurementState = .waitingForImpulse

        do {
            try await audioRecorder.startRecording()
            measurementState = .recording
        } catch {
            errorMessage = error.localizedDescription
            measurementState = .error
        }
    }

    /// Stoppt die Messung und berechnet RT60
    func stopMeasurement() {
        audioRecorder.stopRecording()
        measurementState = .processing

        Task {
            await processMeasurement()
        }
    }

    /// Setzt alles zurück für eine neue Messung
    func resetMeasurement() {
        audioRecorder.reset()
        latestMeasurement = nil
        decayCurve = nil
        bandMeasurements = [:]
        errorMessage = nil
        measurementState = .idle
    }

    /// Exportiert die Messergebnisse als Text
    func exportResults() -> String {
        var output = "Akusti-Scan RT60 Messergebnis\n"
        output += "============================\n\n"

        if let measurement = latestMeasurement {
            output += "Datum: \(formatDate(measurement.timestamp))\n"
            output += "RT60: \(String(format: "%.3f", measurement.rt60Value)) s\n"

            if let t20 = measurement.t20Value {
                output += "T20: \(String(format: "%.3f", t20)) s\n"
            }
            if let t30 = measurement.t30Value {
                output += "T30: \(String(format: "%.3f", t30)) s\n"
            }

            output += "Peak Level: \(String(format: "%.1f", measurement.peakLevel)) dB\n"
            output += "Noise Floor: \(String(format: "%.1f", measurement.noiseFloor)) dB\n"
            output += "Raumtyp: \(selectedRoomType.rawValue)\n"

            if let rating = acousticRating {
                output += "Bewertung: \(rating.rawValue)\n"
            }

            output += "\nFrequenzband-Analyse:\n"
            output += "---------------------\n"

            for band in FrequencyBand.allCases {
                if let bandMeasurement = bandMeasurements[band], bandMeasurement.isValid {
                    output += "\(band.rawValue): \(String(format: "%.3f", bandMeasurement.rt60Value)) s\n"
                }
            }
        }

        return output
    }

    /// Löscht die Messhistorie
    func clearHistory() {
        measurementHistory.removeAll()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Level-Updates vom Recorder
        audioRecorder.$currentLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentLevel)

        audioRecorder.$peakLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$peakLevel)

        // Impuls-Erkennung
        audioRecorder.$isImpulseDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                if detected && self?.measurementState == .waitingForImpulse {
                    self?.measurementState = .recording
                }
            }
            .store(in: &cancellables)

        // Recorder-Status
        audioRecorder.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .permissionDenied:
                    self?.hasPermission = false
                    self?.measurementState = .permissionDenied
                case .error(let message):
                    self?.errorMessage = message
                    self?.measurementState = .error
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func processMeasurement() async {
        let audioSample = audioRecorder.getAudioSample()

        guard audioSample.samples.count > 1000 else {
            errorMessage = "Aufnahme zu kurz"
            measurementState = .error
            return
        }

        // RT60 berechnen
        let measurement = rt60Calculator.calculateRT60(from: audioSample)
        latestMeasurement = measurement

        // Decay-Kurve für Visualisierung
        decayCurve = rt60Calculator.generateDecayCurve(from: audioSample)

        // Frequenzband-Analyse
        if showBandAnalysis {
            bandMeasurements = rt60Calculator.calculateRT60ByBand(from: audioSample)
        }

        // Zur Historie hinzufügen
        if measurement.isValid {
            measurementHistory.insert(measurement, at: 0)
            // Maximal 50 Messungen speichern
            if measurementHistory.count > 50 {
                measurementHistory.removeLast()
            }
        }

        measurementState = .completed
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Measurement State

enum MeasurementState: Equatable {
    case idle
    case permissionDenied
    case waitingForImpulse
    case recording
    case processing
    case completed
    case error

    var displayText: String {
        switch self {
        case .idle:
            return "Bereit"
        case .permissionDenied:
            return "Mikrofonzugriff erforderlich"
        case .waitingForImpulse:
            return "Warte auf Impuls..."
        case .recording:
            return "Aufnahme läuft..."
        case .processing:
            return "Berechne RT60..."
        case .completed:
            return "Messung abgeschlossen"
        case .error:
            return "Fehler"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .permissionDenied: return .orange
        case .waitingForImpulse: return .yellow
        case .recording: return .red
        case .processing: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }
}
