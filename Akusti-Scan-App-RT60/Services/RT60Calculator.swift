//
//  RT60Calculator.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import Foundation
import Accelerate

/// RT60-Berechnungsservice
final class RT60Calculator {
    // MARK: - Configuration

    private let windowSize: Int = 2048
    private let hopSize: Int = 512
    private let smoothingFactor: Int = 5

    // MARK: - Public Methods

    /// Berechnet RT60 aus Audio-Samples
    /// - Parameter audioSample: Die aufgenommenen Audio-Samples
    /// - Returns: RT60-Messergebnis
    func calculateRT60(from audioSample: AudioSample) -> RT60Measurement {
        let samples = audioSample.samples
        let sampleRate = audioSample.sampleRate

        guard samples.count > windowSize else {
            return createInvalidMeasurement(reason: "Zu wenige Samples")
        }

        // 1. Impuls-Position finden
        let impulseIndex = findImpulsePosition(in: samples)

        // 2. Decay-Kurve berechnen (Schroeder-Integration)
        let decayCurve = calculateDecayCurve(
            samples: samples,
            startIndex: impulseIndex,
            sampleRate: sampleRate
        )

        guard decayCurve.levelPoints.count > 10 else {
            return createInvalidMeasurement(reason: "Decay-Kurve zu kurz")
        }

        // 3. Lineare Regression für verschiedene Decay-Bereiche
        let t20Result = calculateDecayTime(
            decayCurve: decayCurve,
            startDB: -5,
            endDB: -25,
            extrapolationFactor: 3.0
        )

        let t30Result = calculateDecayTime(
            decayCurve: decayCurve,
            startDB: -5,
            endDB: -35,
            extrapolationFactor: 2.0
        )

        // 4. RT60 direkt messen (wenn möglich)
        let rt60Direct = calculateDecayTime(
            decayCurve: decayCurve,
            startDB: -5,
            endDB: -65,
            extrapolationFactor: 1.0
        )

        // Beste Schätzung verwenden
        let rt60Value = rt60Direct ?? t30Result ?? t20Result ?? 0

        // Peak und Noise Floor berechnen
        let peakLevel = 20 * log10(Double(samples.map { abs($0) }.max() ?? 1e-10))
        let noiseFloor = calculateNoiseFloor(samples: samples, sampleRate: sampleRate)

        return RT60Measurement(
            rt60Value: rt60Value,
            t20Value: t20Result,
            t30Value: t30Result,
            peakLevel: peakLevel,
            noiseFloor: noiseFloor,
            frequency: .broadband,
            isValid: rt60Value > 0.05 && rt60Value < 15.0
        )
    }

    /// Berechnet RT60 für verschiedene Frequenzbänder
    func calculateRT60ByBand(from audioSample: AudioSample) -> [FrequencyBand: RT60Measurement] {
        var results: [FrequencyBand: RT60Measurement] = [:]

        // Breitband
        results[.broadband] = calculateRT60(from: audioSample)

        // Oktavband-Filter anwenden und RT60 berechnen
        for band in FrequencyBand.allCases where band != .broadband {
            let filteredSamples = applyBandpassFilter(
                samples: audioSample.samples,
                centerFrequency: band.centerFrequency,
                sampleRate: audioSample.sampleRate
            )

            let filteredAudioSample = AudioSample(
                samples: filteredSamples,
                sampleRate: audioSample.sampleRate,
                channelCount: 1,
                duration: audioSample.duration
            )

            var measurement = calculateRT60(from: filteredAudioSample)
            measurement = RT60Measurement(
                id: measurement.id,
                timestamp: measurement.timestamp,
                rt60Value: measurement.rt60Value,
                t20Value: measurement.t20Value,
                t30Value: measurement.t30Value,
                peakLevel: measurement.peakLevel,
                noiseFloor: measurement.noiseFloor,
                frequency: band,
                isValid: measurement.isValid
            )
            results[band] = measurement
        }

        return results
    }

    /// Generiert Decay-Kurve für Visualisierung
    func generateDecayCurve(from audioSample: AudioSample) -> DecayCurve {
        let samples = audioSample.samples
        let sampleRate = audioSample.sampleRate

        let impulseIndex = findImpulsePosition(in: samples)
        return calculateDecayCurve(samples: samples, startIndex: impulseIndex, sampleRate: sampleRate)
    }

    // MARK: - Private Methods

    /// Findet die Position des Impulses (Maximum) in den Samples
    private func findImpulsePosition(in samples: [Float]) -> Int {
        var maxIndex = 0
        var maxValue: Float = 0

        for (index, sample) in samples.enumerated() {
            let absValue = abs(sample)
            if absValue > maxValue {
                maxValue = absValue
                maxIndex = index
            }
        }

        return maxIndex
    }

    /// Berechnet die Decay-Kurve mittels Schroeder-Integration
    private func calculateDecayCurve(samples: [Float], startIndex: Int, sampleRate: Double) -> DecayCurve {
        guard startIndex < samples.count else {
            return DecayCurve(
                timePoints: [],
                levelPoints: [],
                regressionSlope: 0,
                regressionIntercept: 0,
                correlationCoefficient: 0
            )
        }

        // Samples nach dem Impuls
        let decaySamples = Array(samples[startIndex...])

        // Quadrieren der Samples
        let squaredSamples = decaySamples.map { $0 * $0 }

        // Rückwärts-Integration (Schroeder)
        var schroederCurve = [Double](repeating: 0, count: squaredSamples.count)
        var runningSum: Double = 0

        for i in stride(from: squaredSamples.count - 1, through: 0, by: -1) {
            runningSum += Double(squaredSamples[i])
            schroederCurve[i] = runningSum
        }

        // Normalisieren und in dB umrechnen
        let maxValue = schroederCurve[0]
        var levelPoints: [Double] = []
        var timePoints: [Double] = []

        let decimationFactor = max(1, schroederCurve.count / 1000)

        for i in stride(from: 0, to: schroederCurve.count, by: decimationFactor) {
            let normalized = schroederCurve[i] / maxValue
            if normalized > 1e-10 {
                let dB = 10 * log10(normalized)
                if dB > -80 {
                    timePoints.append(Double(i) / sampleRate)
                    levelPoints.append(dB)
                }
            }
        }

        // Lineare Regression berechnen
        let (slope, intercept, correlation) = linearRegression(x: timePoints, y: levelPoints)

        return DecayCurve(
            timePoints: timePoints,
            levelPoints: levelPoints,
            regressionSlope: slope,
            regressionIntercept: intercept,
            correlationCoefficient: correlation
        )
    }

    /// Berechnet die Abklingzeit für einen bestimmten dB-Bereich
    private func calculateDecayTime(
        decayCurve: DecayCurve,
        startDB: Double,
        endDB: Double,
        extrapolationFactor: Double
    ) -> Double? {
        // Punkte im gewünschten Bereich finden
        var rangeTimePoints: [Double] = []
        var rangeLevelPoints: [Double] = []

        for i in 0..<decayCurve.timePoints.count {
            let level = decayCurve.levelPoints[i]
            if level <= startDB && level >= endDB {
                rangeTimePoints.append(decayCurve.timePoints[i])
                rangeLevelPoints.append(level)
            }
        }

        guard rangeTimePoints.count >= 5 else { return nil }

        // Lineare Regression
        let (slope, _, correlation) = linearRegression(x: rangeTimePoints, y: rangeLevelPoints)

        // Korrelation prüfen
        guard abs(correlation) > 0.9 else { return nil }

        // RT60 berechnen: Zeit für 60 dB Abfall
        guard slope < 0 else { return nil }
        let decayTime = -60.0 / slope * extrapolationFactor / (endDB - startDB) * (-60)

        // Plausibilitätsprüfung
        guard decayTime > 0.05 && decayTime < 15.0 else { return nil }

        return decayTime
    }

    /// Lineare Regression
    private func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double, correlation: Double) {
        guard x.count == y.count && x.count > 1 else {
            return (0, 0, 0)
        }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return (0, 0, 0) }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // Korrelationskoeffizient
        let correlationNumerator = n * sumXY - sumX * sumY
        let correlationDenominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        let correlation = correlationDenominator != 0 ? correlationNumerator / correlationDenominator : 0

        return (slope, intercept, correlation)
    }

    /// Berechnet den Rauschboden
    private func calculateNoiseFloor(samples: [Float], sampleRate: Double) -> Double {
        // Letzte 10% der Samples für Noise Floor
        let noiseStartIndex = Int(Double(samples.count) * 0.9)
        guard noiseStartIndex < samples.count else { return -60 }

        let noiseSamples = Array(samples[noiseStartIndex...])
        let rms = sqrt(noiseSamples.map { $0 * $0 }.reduce(0, +) / Float(noiseSamples.count))

        return 20 * log10(Double(max(rms, 1e-10)))
    }

    /// Wendet einen Bandpass-Filter an
    private func applyBandpassFilter(samples: [Float], centerFrequency: Double, sampleRate: Double) -> [Float] {
        let bandwidth = centerFrequency * 0.7071 // Oktavband

        let lowFreq = centerFrequency / sqrt(2)
        let highFreq = centerFrequency * sqrt(2)

        // Einfacher Butterworth-ähnlicher Filter (2. Ordnung)
        let normalizedLow = lowFreq / (sampleRate / 2)
        let normalizedHigh = highFreq / (sampleRate / 2)

        // Biquad-Koeffizienten für Bandpass
        let Q = centerFrequency / bandwidth
        let omega = 2 * Double.pi * centerFrequency / sampleRate
        let alpha = sin(omega) / (2 * Q)
        let cosOmega = cos(omega)

        let b0 = alpha
        let b1: Double = 0
        let b2 = -alpha
        let a0 = 1 + alpha
        let a1 = -2 * cosOmega
        let a2 = 1 - alpha

        // Normalisieren
        let b0n = Float(b0 / a0)
        let b1n = Float(b1 / a0)
        let b2n = Float(b2 / a0)
        let a1n = Float(a1 / a0)
        let a2n = Float(a2 / a0)

        // Filter anwenden
        var filteredSamples = [Float](repeating: 0, count: samples.count)
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<samples.count {
            let x0 = samples[i]
            let y0 = b0n * x0 + b1n * x1 + b2n * x2 - a1n * y1 - a2n * y2

            filteredSamples[i] = y0

            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }

        return filteredSamples
    }

    /// Erstellt eine ungültige Messung
    private func createInvalidMeasurement(reason: String) -> RT60Measurement {
        return RT60Measurement(
            rt60Value: 0,
            t20Value: nil,
            t30Value: nil,
            peakLevel: -120,
            noiseFloor: -120,
            frequency: .broadband,
            isValid: false
        )
    }
}
