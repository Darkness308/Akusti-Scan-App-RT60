//
//  SweptSineGenerator.swift
//  Akusti-Scan-App-RT60
//
//  Exponential Swept Sine (ESS) generator for impulse response measurement
//  Based on Farina's method for room acoustics
//

import AVFoundation
import Accelerate

/// Measurement method for RT60
enum MeasurementMethod: String, CaseIterable, Identifiable {
    case impulse = "Impuls (Klatschen/Ballon)"
    case sweptSine = "Swept Sine (ESS)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .impulse:
            return "Klatschen Sie in die Hände oder platzen Sie einen Ballon"
        case .sweptSine:
            return "Spielt einen Sinus-Sweep ab und nimmt die Raumantwort auf"
        }
    }
}

/// Exponential Swept Sine generator and processor
@MainActor
@Observable
final class SweptSineGenerator {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var recordedSamples: [Float] = []

    private(set) var isPlaying = false
    private(set) var isRecording = false
    private(set) var progress: Float = 0

    /// Sample rate
    let sampleRate: Double = 44100

    /// Sweep parameters
    let sweepDuration: Double = 3.0  // seconds
    let startFrequency: Double = 20.0  // Hz
    let endFrequency: Double = 20000.0  // Hz

    // MARK: - Sweep Generation

    /// Generate exponential swept sine signal
    func generateSweep() -> [Float] {
        let sampleCount = Int(sweepDuration * sampleRate)
        var sweep = [Float](repeating: 0, count: sampleCount)

        // Exponential sweep rate
        let sweepRate = log(endFrequency / startFrequency) / sweepDuration

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate

            // Exponential frequency increase: f(t) = f1 * exp(t * rate)
            let instantFreq = startFrequency * exp(t * sweepRate)

            // Phase integral for exponential sweep
            let phase = 2.0 * Double.pi * startFrequency / sweepRate * (exp(t * sweepRate) - 1)

            // Apply amplitude envelope (fade in/out)
            var amplitude = 0.8
            let fadeLength = 0.05 * sweepDuration
            if t < fadeLength {
                amplitude *= t / fadeLength
            } else if t > sweepDuration - fadeLength {
                amplitude *= (sweepDuration - t) / fadeLength
            }

            sweep[i] = Float(amplitude * sin(phase))
        }

        return sweep
    }

    /// Generate inverse filter for deconvolution
    func generateInverseFilter() -> [Float] {
        let sampleCount = Int(sweepDuration * sampleRate)
        var inverse = [Float](repeating: 0, count: sampleCount)

        let sweepRate = log(endFrequency / startFrequency) / sweepDuration

        for i in 0..<sampleCount {
            // Time-reversed sweep
            let t = sweepDuration - Double(i) / sampleRate

            let instantFreq = startFrequency * exp(t * sweepRate)
            let phase = 2.0 * Double.pi * startFrequency / sweepRate * (exp(t * sweepRate) - 1)

            // Amplitude modulation to compensate for sweep rate
            // Higher frequencies get less energy in ESS, so inverse needs more gain
            let amplitudeModulation = startFrequency / instantFreq

            inverse[i] = Float(amplitudeModulation * sin(-phase))
        }

        // Normalize
        var maxVal: Float = 0
        vDSP_maxv(inverse, 1, &maxVal, vDSP_Length(inverse.count))
        if maxVal > 0 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(inverse, 1, &scale, &inverse, 1, vDSP_Length(inverse.count))
        }

        return inverse
    }

    // MARK: - Deconvolution

    /// Extract impulse response from recorded sweep using deconvolution
    func deconvolve(recordedSignal: [Float]) -> [Float] {
        let sweepSamples = Int(sweepDuration * sampleRate)
        let irLength = sweepSamples  // Expected IR length

        // Use FFT-based convolution for efficiency
        let fftLength = nextPowerOfTwo(recordedSignal.count + sweepSamples)

        // Generate inverse filter
        let inverseFilter = generateInverseFilter()

        // Pad signals to FFT length
        var paddedRecorded = [Float](repeating: 0, count: fftLength)
        var paddedInverse = [Float](repeating: 0, count: fftLength)

        for i in 0..<min(recordedSignal.count, fftLength) {
            paddedRecorded[i] = recordedSignal[i]
        }
        for i in 0..<min(inverseFilter.count, fftLength) {
            paddedInverse[i] = inverseFilter[i]
        }

        // Perform FFT-based convolution
        let impulseResponse = fftConvolve(paddedRecorded, paddedInverse, fftLength: fftLength)

        // Extract the main impulse response (skip initial delay)
        // The peak should be near the center of the convolution result
        let peakIndex = findPeakIndex(impulseResponse)
        let startIndex = max(0, peakIndex - 1000)  // 1000 samples before peak
        let endIndex = min(impulseResponse.count, peakIndex + irLength)

        return Array(impulseResponse[startIndex..<endIndex])
    }

    /// FFT-based convolution
    private func fftConvolve(_ signal1: [Float], _ signal2: [Float], fftLength: Int) -> [Float] {
        let log2n = vDSP_Length(log2(Double(fftLength)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return signal1
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Prepare split complex arrays
        var realp1 = [Float](repeating: 0, count: fftLength / 2)
        var imagp1 = [Float](repeating: 0, count: fftLength / 2)
        var realp2 = [Float](repeating: 0, count: fftLength / 2)
        var imagp2 = [Float](repeating: 0, count: fftLength / 2)

        var splitComplex1 = DSPSplitComplex(realp: &realp1, imagp: &imagp1)
        var splitComplex2 = DSPSplitComplex(realp: &realp2, imagp: &imagp2)

        // Convert to split complex
        signal1.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex1, 1, vDSP_Length(fftLength / 2))
            }
        }
        signal2.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex2, 1, vDSP_Length(fftLength / 2))
            }
        }

        // Forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex1, 1, log2n, FFTDirection(kFFTDirection_Forward))
        vDSP_fft_zrip(fftSetup, &splitComplex2, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Complex multiplication (convolution in frequency domain)
        var realResult = [Float](repeating: 0, count: fftLength / 2)
        var imagResult = [Float](repeating: 0, count: fftLength / 2)

        for i in 0..<fftLength / 2 {
            realResult[i] = realp1[i] * realp2[i] - imagp1[i] * imagp2[i]
            imagResult[i] = realp1[i] * imagp2[i] + imagp1[i] * realp2[i]
        }

        var resultSplit = DSPSplitComplex(realp: &realResult, imagp: &imagResult)

        // Inverse FFT
        vDSP_fft_zrip(fftSetup, &resultSplit, 1, log2n, FFTDirection(kFFTDirection_Inverse))

        // Convert back to real
        var result = [Float](repeating: 0, count: fftLength)
        result.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength / 2) { complexPtr in
                vDSP_ztoc(&resultSplit, 1, complexPtr, 2, vDSP_Length(fftLength / 2))
            }
        }

        // Scale
        var scale = 1.0 / Float(fftLength)
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(result.count))

        return result
    }

    // MARK: - Impulse Detection

    /// Detect impulse in recording (clap, balloon pop)
    func detectImpulse(samples: [Float], threshold: Float = 0.3) -> (startIndex: Int, peakIndex: Int)? {
        guard !samples.isEmpty else { return nil }

        // Find peak amplitude
        var peakIndex: vDSP_Length = 0
        var peakValue: Float = 0
        vDSP_maxvi(samples.map { abs($0) }, 1, &peakValue, &peakIndex, vDSP_Length(samples.count))

        guard peakValue > threshold else { return nil }

        // Find start of impulse (first crossing of threshold * peak)
        let startThreshold = peakValue * 0.1
        var startIndex = Int(peakIndex)

        for i in stride(from: Int(peakIndex), through: 0, by: -1) {
            if abs(samples[i]) < startThreshold {
                startIndex = i
                break
            }
        }

        return (startIndex, Int(peakIndex))
    }

    /// Extract impulse response from impulse recording
    func extractImpulseResponse(samples: [Float]) -> [Float]? {
        guard let (startIndex, _) = detectImpulse(samples: samples) else {
            return nil
        }

        // Extract from start of impulse to end of recording (or reasonable length)
        let maxIRLength = Int(sampleRate * 5)  // Max 5 seconds of decay
        let endIndex = min(samples.count, startIndex + maxIRLength)

        return Array(samples[startIndex..<endIndex])
    }

    // MARK: - Audio Playback and Recording

    /// Play sweep and record response
    func measureWithSweep() async throws -> [Float] {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement)
        try session.setActive(true)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Generate sweep
        let sweep = generateSweep()

        // Create buffer
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sweep.count))!
        buffer.frameLength = AVAudioFrameCount(sweep.count)

        for i in 0..<sweep.count {
            buffer.floatChannelData?[0][i] = sweep[i]
        }

        // Setup recording tap
        recordedSamples.removeAll()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

            Task { @MainActor in
                self.recordedSamples.append(contentsOf: samples)
                self.progress = min(1.0, Float(self.recordedSamples.count) / Float(self.sweepDuration * self.sampleRate * 2))
            }
        }

        // Start engine and playback
        try engine.start()
        audioEngine = engine
        playerNode = player
        isPlaying = true
        isRecording = true

        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        player.play()

        // Wait for playback plus decay time
        let totalDuration = sweepDuration + 2.0  // 2 seconds for decay
        try await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))

        // Stop recording
        inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        progress = 1.0

        // Deconvolve to get impulse response
        return deconvolve(recordedSignal: recordedSamples)
    }

    // MARK: - Helpers

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    private func findPeakIndex(_ samples: [Float]) -> Int {
        var peakIndex: vDSP_Length = 0
        var peakValue: Float = 0
        let absSamples = samples.map { abs($0) }
        vDSP_maxvi(absSamples, 1, &peakValue, &peakIndex, vDSP_Length(samples.count))
        return Int(peakIndex)
    }
}
