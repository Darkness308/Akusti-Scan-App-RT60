//
//  RT60Measurement.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import Foundation

/// Repräsentiert eine einzelne RT60-Messung
struct RT60Measurement: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let rt60Value: Double // in Sekunden
    let t20Value: Double? // T20 extrapoliert auf RT60
    let t30Value: Double? // T30 extrapoliert auf RT60
    let peakLevel: Double // in dB
    let noiseFloor: Double // in dB
    let frequency: FrequencyBand
    let isValid: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rt60Value: Double,
        t20Value: Double? = nil,
        t30Value: Double? = nil,
        peakLevel: Double,
        noiseFloor: Double,
        frequency: FrequencyBand = .broadband,
        isValid: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rt60Value = rt60Value
        self.t20Value = t20Value
        self.t30Value = t30Value
        self.peakLevel = peakLevel
        self.noiseFloor = noiseFloor
        self.frequency = frequency
        self.isValid = isValid
    }
}

/// Frequenzbänder für oktavbasierte Analyse
enum FrequencyBand: String, CaseIterable, Codable {
    case broadband = "Breitband"
    case hz125 = "125 Hz"
    case hz250 = "250 Hz"
    case hz500 = "500 Hz"
    case hz1000 = "1 kHz"
    case hz2000 = "2 kHz"
    case hz4000 = "4 kHz"

    var centerFrequency: Double {
        switch self {
        case .broadband: return 0
        case .hz125: return 125
        case .hz250: return 250
        case .hz500: return 500
        case .hz1000: return 1000
        case .hz2000: return 2000
        case .hz4000: return 4000
        }
    }
}

/// Bewertung der Raumakustik basierend auf RT60
enum RoomAcousticRating: String {
    case tooLive = "Zu hallig"
    case live = "Hallig"
    case balanced = "Ausgewogen"
    case dry = "Trocken"
    case tooDry = "Zu trocken"

    static func fromRT60(_ value: Double, roomType: RoomType) -> RoomAcousticRating {
        let optimalRange = roomType.optimalRT60Range

        if value < optimalRange.lowerBound * 0.5 {
            return .tooDry
        } else if value < optimalRange.lowerBound {
            return .dry
        } else if value <= optimalRange.upperBound {
            return .balanced
        } else if value <= optimalRange.upperBound * 1.5 {
            return .live
        } else {
            return .tooLive
        }
    }
}

/// Verschiedene Raumtypen mit ihren optimalen RT60-Werten
enum RoomType: String, CaseIterable {
    case recordingStudio = "Tonstudio"
    case homeTheater = "Heimkino"
    case livingRoom = "Wohnzimmer"
    case classroom = "Klassenzimmer"
    case concertHall = "Konzertsaal"
    case church = "Kirche"

    var optimalRT60Range: ClosedRange<Double> {
        switch self {
        case .recordingStudio: return 0.2...0.4
        case .homeTheater: return 0.3...0.5
        case .livingRoom: return 0.4...0.6
        case .classroom: return 0.4...0.7
        case .concertHall: return 1.5...2.5
        case .church: return 2.0...4.0
        }
    }
}

/// Audio-Sample für die Verarbeitung
struct AudioSample {
    let samples: [Float]
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval

    var peakAmplitude: Float {
        samples.map { abs($0) }.max() ?? 0
    }

    var rmsLevel: Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    var rmsLevelDB: Double {
        let rms = Double(rmsLevel)
        guard rms > 0 else { return -120 }
        return 20 * log10(rms)
    }
}

/// Decay-Kurve für Visualisierung
struct DecayCurve: Identifiable {
    let id = UUID()
    let timePoints: [Double] // in Sekunden
    let levelPoints: [Double] // in dB
    let regressionSlope: Double
    let regressionIntercept: Double
    let correlationCoefficient: Double
}
