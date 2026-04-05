//
//  AcousticsCalculator.swift
//  Akusti-Scan-App-RT60
//
//  Acoustic calculations including Sabine, Eyring, and measured RT60
//

import Foundation
import Accelerate

/// Complete acoustic analysis result
struct AcousticAnalysis: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let roomName: String
    let roomVolume: Double
    let roomSurfaceArea: Double

    // Measured values (from audio recording)
    let measuredRT60: [FrequencyBand: Double]?

    // Calculated values (from room model)
    let sabineRT60: [FrequencyBand: Double]
    let eyringRT60: [FrequencyBand: Double]

    // Additional metrics
    let t20: [FrequencyBand: Double]?
    let t30: [FrequencyBand: Double]?
    let edt: [FrequencyBand: Double]?
    let clarity: [FrequencyBand: Double]?  // C80

    // Averages
    var averageMeasuredRT60: Double? {
        guard let measured = measuredRT60 else { return nil }
        let values = Array(measured.values)
        return values.reduce(0, +) / Double(values.count)
    }

    var averageSabineRT60: Double {
        let values = Array(sabineRT60.values)
        return values.reduce(0, +) / Double(values.count)
    }

    var averageEyringRT60: Double {
        let values = Array(eyringRT60.values)
        return values.reduce(0, +) / Double(values.count)
    }

    /// Room acoustic quality assessment
    var qualityAssessment: String {
        let rt60 = averageMeasuredRT60 ?? averageSabineRT60

        if rt60 < 0.3 {
            return "Sehr trocken - ideal für Aufnahmestudios"
        } else if rt60 < 0.5 {
            return "Trocken - gut für Sprache und Heimkino"
        } else if rt60 < 0.8 {
            return "Ausgewogen - geeignet für Mehrzweckräume"
        } else if rt60 < 1.2 {
            return "Hallig - geeignet für Musik"
        } else if rt60 < 2.0 {
            return "Sehr hallig - typisch für Konzertsäle"
        } else {
            return "Extrem hallig - typisch für Kirchen"
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        roomName: String,
        roomVolume: Double,
        roomSurfaceArea: Double,
        measuredRT60: [FrequencyBand: Double]? = nil,
        sabineRT60: [FrequencyBand: Double],
        eyringRT60: [FrequencyBand: Double],
        t20: [FrequencyBand: Double]? = nil,
        t30: [FrequencyBand: Double]? = nil,
        edt: [FrequencyBand: Double]? = nil,
        clarity: [FrequencyBand: Double]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.roomName = roomName
        self.roomVolume = roomVolume
        self.roomSurfaceArea = roomSurfaceArea
        self.measuredRT60 = measuredRT60
        self.sabineRT60 = sabineRT60
        self.eyringRT60 = eyringRT60
        self.t20 = t20
        self.t30 = t30
        self.edt = edt
        self.clarity = clarity
    }
}

/// Calculator for room acoustics
final class AcousticsCalculator: Sendable {

    // MARK: - Properties

    private let sampleRate: Double

    // MARK: - Initialization

    init(sampleRate: Double = 44100) {
        self.sampleRate = sampleRate
    }

    // MARK: - Sabine Formula

    /// Calculate RT60 using Sabine formula
    /// RT60 = 0.161 * V / A
    /// where V = volume (m³), A = equivalent absorption area (m²)
    func sabineRT60(room: Room) -> [FrequencyBand: Double] {
        var results: [FrequencyBand: Double] = [:]

        for band in FrequencyBand.allCases {
            let absorptionArea = totalAbsorptionArea(room: room, at: band)
            let airAbsorption = room.airAbsorption(at: band) * 4 * room.volume

            let rt60 = 0.161 * room.volume / (absorptionArea + airAbsorption)
            results[band] = max(0.1, min(10.0, rt60))  // Clamp to reasonable range
        }

        return results
    }

    // MARK: - Eyring Formula

    /// Calculate RT60 using Eyring formula (more accurate for high absorption)
    /// RT60 = 0.161 * V / (-S * ln(1 - α_avg) + 4mV)
    func eyringRT60(room: Room) -> [FrequencyBand: Double] {
        var results: [FrequencyBand: Double] = [:]

        for band in FrequencyBand.allCases {
            let avgAbsorption = averageAbsorptionCoefficient(room: room, at: band)
            let airAbsorption = room.airAbsorption(at: band) * 4 * room.volume

            // Eyring formula
            let denominator = -room.totalSurfaceArea * log(1 - avgAbsorption) + airAbsorption

            guard denominator > 0 else {
                results[band] = 0.1
                continue
            }

            let rt60 = 0.161 * room.volume / denominator
            results[band] = max(0.1, min(10.0, rt60))
        }

        return results
    }

    // MARK: - Measured RT60 with Frequency Bands

    /// Calculate RT60 from audio samples with octave band analysis
    func measureRT60(samples: [Float], filterByBand: Bool = true) -> [FrequencyBand: Double] {
        if filterByBand {
            var results: [FrequencyBand: Double] = [:]

            for band in FrequencyBand.allCases {
                let filteredSamples = bandpassFilter(samples: samples, band: band)
                if let rt60 = calculateRT60FromSamples(filteredSamples) {
                    results[band] = rt60
                }
            }

            return results
        } else {
            // Broadband analysis
            if let rt60 = calculateRT60FromSamples(samples) {
                var results: [FrequencyBand: Double] = [:]
                for band in FrequencyBand.allCases {
                    results[band] = rt60
                }
                return results
            }
            return [:]
        }
    }

    /// Calculate T20, T30, EDT from samples
    func measureDetailedMetrics(samples: [Float]) -> (t20: Double?, t30: Double?, edt: Double?) {
        let schroederCurve = schroederIntegration(samples)
        let dbCurve = convertToDecibels(schroederCurve)

        let t20 = try? calculateDecayTime(dbCurve, from: -5, to: -25, extrapolateTo60: true)
        let t30 = try? calculateDecayTime(dbCurve, from: -5, to: -35, extrapolateTo60: true)
        let edt = try? calculateDecayTime(dbCurve, from: 0, to: -10, extrapolateTo60: true)

        return (t20, t30, edt)
    }

    // MARK: - Complete Analysis

    /// Perform complete acoustic analysis
    func analyzeRoom(room: Room, audioSamples: [Float]? = nil) -> AcousticAnalysis {
        let sabine = sabineRT60(room: room)
        let eyring = eyringRT60(room: room)

        var measured: [FrequencyBand: Double]?
        var t20Values: [FrequencyBand: Double]?
        var t30Values: [FrequencyBand: Double]?
        var edtValues: [FrequencyBand: Double]?

        if let samples = audioSamples, !samples.isEmpty {
            measured = measureRT60(samples: samples, filterByBand: true)

            // Calculate detailed metrics for each band
            t20Values = [:]
            t30Values = [:]
            edtValues = [:]

            for band in FrequencyBand.allCases {
                let filteredSamples = bandpassFilter(samples: samples, band: band)
                let metrics = measureDetailedMetrics(samples: filteredSamples)

                if let t20 = metrics.t20 { t20Values?[band] = t20 }
                if let t30 = metrics.t30 { t30Values?[band] = t30 }
                if let edt = metrics.edt { edtValues?[band] = edt }
            }
        }

        return AcousticAnalysis(
            roomName: room.name,
            roomVolume: room.volume,
            roomSurfaceArea: room.totalSurfaceArea,
            measuredRT60: measured,
            sabineRT60: sabine,
            eyringRT60: eyring,
            t20: t20Values,
            t30: t30Values,
            edt: edtValues
        )
    }

    // MARK: - Private Helpers

    private func totalAbsorptionArea(room: Room, at band: FrequencyBand) -> Double {
        if room.surfaces.isEmpty {
            // Default absorption coefficient if no surfaces defined
            return room.totalSurfaceArea * 0.1
        }

        return room.surfaces.reduce(0.0) { sum, surface in
            sum + surface.equivalentAbsorptionArea(at: band)
        }
    }

    private func averageAbsorptionCoefficient(room: Room, at band: FrequencyBand) -> Double {
        let totalArea = totalAbsorptionArea(room: room, at: band)
        return min(0.99, totalArea / room.totalSurfaceArea)  // Cap at 0.99 for Eyring
    }

    /// Apply proper biquad bandpass filter for octave band analysis
    /// Uses Audio EQ Cookbook formulas (Robert Bristow-Johnson)
    private func bandpassFilter(samples: [Float], band: FrequencyBand) -> [Float] {
        guard samples.count > 0 else { return samples }

        let centerFreq = band.frequency
        let q = 1.414  // Q for octave bandwidth (sqrt(2))

        // Calculate biquad coefficients using Audio EQ Cookbook BPF formula
        let w0 = 2.0 * Double.pi * centerFreq / sampleRate
        let alpha = sin(w0) / (2.0 * q)

        let b0 = alpha
        let b1 = 0.0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(w0)
        let a2 = 1.0 - alpha

        // Normalize coefficients by a0
        let coefficients: [Double] = [
            b0 / a0, b1 / a0, b2 / a0,  // b0, b1, b2
            a1 / a0, a2 / a0            // a1, a2
        ]

        // Apply biquad filter using vDSP
        var filtered = [Float](repeating: 0, count: samples.count)
        var delay = [Float](repeating: 0, count: 4)  // z^-1, z^-2 for input and output

        // Second-order IIR (biquad) direct form II transposed
        for i in 0..<samples.count {
            let input = Double(samples[i])

            // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
            let output = coefficients[0] * input +
                        coefficients[1] * Double(delay[0]) +
                        coefficients[2] * Double(delay[1]) -
                        coefficients[3] * Double(delay[2]) -
                        coefficients[4] * Double(delay[3])

            // Update delay lines
            delay[1] = delay[0]
            delay[0] = samples[i]
            delay[3] = delay[2]
            delay[2] = Float(output)

            filtered[i] = Float(output)
        }

        // Apply filter in reverse for zero-phase filtering (forward-backward)
        var reversedFiltered = [Float](repeating: 0, count: samples.count)
        delay = [Float](repeating: 0, count: 4)

        for i in stride(from: samples.count - 1, through: 0, by: -1) {
            let input = Double(filtered[i])

            let output = coefficients[0] * input +
                        coefficients[1] * Double(delay[0]) +
                        coefficients[2] * Double(delay[1]) -
                        coefficients[3] * Double(delay[2]) -
                        coefficients[4] * Double(delay[3])

            delay[1] = delay[0]
            delay[0] = filtered[i]
            delay[3] = delay[2]
            delay[2] = Float(output)

            reversedFiltered[i] = Float(output)
        }

        return reversedFiltered
    }

    private func calculateRT60FromSamples(_ samples: [Float]) -> Double? {
        guard samples.count > Int(sampleRate * 0.1) else { return nil }

        let schroederCurve = schroederIntegration(samples)
        let dbCurve = convertToDecibels(schroederCurve)

        return try? calculateDecayTime(dbCurve, from: -5, to: -35, extrapolateTo60: true)
    }

    private func schroederIntegration(_ samples: [Float]) -> [Float] {
        // Square samples
        var squared = [Float](repeating: 0, count: samples.count)
        vDSP_vsq(samples, 1, &squared, 1, vDSP_Length(samples.count))

        // Backward cumulative sum
        var result = [Float](repeating: 0, count: samples.count)
        var runningSum: Float = 0

        for i in stride(from: samples.count - 1, through: 0, by: -1) {
            runningSum += squared[i]
            result[i] = runningSum
        }

        return result
    }

    private func convertToDecibels(_ values: [Float]) -> [Float] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return values
        }

        return values.map { value in
            guard value > 0 else { return -100 }
            return 10 * log10(value / maxValue)
        }
    }

    private func calculateDecayTime(
        _ dbCurve: [Float],
        from startDB: Float,
        to endDB: Float,
        extrapolateTo60: Bool = true
    ) throws -> Double {
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

        let sampleCount = end - start
        let decayTime = Double(sampleCount) / sampleRate

        if extrapolateTo60 {
            let measuredDecay = abs(endDB - startDB)
            return decayTime * (60.0 / Double(measuredDecay))
        }

        return decayTime
    }
}
