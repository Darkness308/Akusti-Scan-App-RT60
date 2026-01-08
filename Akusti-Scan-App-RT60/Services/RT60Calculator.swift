//
//  RT60Calculator.swift
//  Akusti-Scan-App-RT60
//
//  RT60 reverberation time calculation using Schroeder method
//

import Accelerate
import Foundation

/// Errors during RT60 calculation
enum RT60Error: Error, LocalizedError {
    case insufficientData
    case calculationFailed
    case invalidDecayRange

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Nicht genügend Audiodaten für RT60-Berechnung."
        case .calculationFailed:
            return "RT60-Berechnung fehlgeschlagen."
        case .invalidDecayRange:
            return "Ungültiger Decay-Bereich in den Audiodaten."
        }
    }
}

/// Result of RT60 calculation
struct RT60Result: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let rt60: Double          // RT60 in seconds
    let t20: Double?          // T20 (extrapolated from -5 to -25 dB)
    let t30: Double?          // T30 (extrapolated from -5 to -35 dB)
    let edt: Double?          // Early Decay Time
    let frequencyBand: String // e.g., "1kHz", "Broadband"

    var formattedRT60: String {
        String(format: "%.2f s", rt60)
    }
}

/// Calculator for RT60 reverberation time using Schroeder backward integration
final class RT60Calculator: Sendable {

    // MARK: - Properties

    private let sampleRate: Double

    // MARK: - Initialization

    init(sampleRate: Double = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - RT60 Calculation

    /// Calculate RT60 from audio samples using Schroeder method
    /// - Parameter samples: Audio samples containing impulse response or decay
    /// - Returns: RT60Result with calculated values
    func calculateRT60(from samples: [Float]) throws -> RT60Result {
        guard samples.count > Int(sampleRate * 0.1) else {
            throw RT60Error.insufficientData
        }

        // Step 1: Square the samples (energy)
        var squaredSamples = [Float](repeating: 0, count: samples.count)
        vDSP_vsq(samples, 1, &squaredSamples, 1, vDSP_Length(samples.count))

        // Step 2: Schroeder backward integration
        let schroederCurve = schroederIntegration(squaredSamples)

        // Step 3: Convert to dB
        let dbCurve = convertToDecibels(schroederCurve)

        // Step 4: Find decay slope and calculate RT60
        let rt60 = try calculateDecayTime(dbCurve, from: -5, to: -35)

        // Calculate additional metrics
        let t20 = try? calculateDecayTime(dbCurve, from: -5, to: -25)
        let t30 = try? calculateDecayTime(dbCurve, from: -5, to: -35)
        let edt = try? calculateDecayTime(dbCurve, from: 0, to: -10)

        return RT60Result(
            timestamp: Date(),
            rt60: rt60,
            t20: t20,
            t30: t30,
            edt: edt,
            frequencyBand: "Broadband"
        )
    }

    // MARK: - Private Methods

    /// Perform Schroeder backward integration
    private func schroederIntegration(_ squaredSamples: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: squaredSamples.count)

        // Backward cumulative sum
        var runningSum: Float = 0
        for i in stride(from: squaredSamples.count - 1, through: 0, by: -1) {
            runningSum += squaredSamples[i]
            result[i] = runningSum
        }

        return result
    }

    /// Convert linear values to decibels
    private func convertToDecibels(_ values: [Float]) -> [Float] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return values
        }

        return values.map { value in
            guard value > 0 else { return -100 }
            return 10 * log10(value / maxValue)
        }
    }

    /// Calculate decay time between two dB levels
    private func calculateDecayTime(_ dbCurve: [Float], from startDB: Float, to endDB: Float) throws -> Double {
        // Find indices where curve crosses start and end dB levels
        var startIndex: Int?
        var endIndex: Int?

        for (index, value) in dbCurve.enumerated() {
            if startIndex == nil && value <= startDB {
                startIndex = index
            }
            if startIndex != nil && endIndex == nil && value <= endDB {
                endIndex = index
                break
            }
        }

        guard let start = startIndex, let end = endIndex, end > start else {
            throw RT60Error.invalidDecayRange
        }

        // Calculate time for this decay
        let sampleCount = end - start
        let decayTime = Double(sampleCount) / sampleRate

        // Extrapolate to 60 dB decay (RT60)
        let measuredDecay = abs(endDB - startDB)
        let rt60 = decayTime * (60.0 / Double(measuredDecay))

        return rt60
    }
}
