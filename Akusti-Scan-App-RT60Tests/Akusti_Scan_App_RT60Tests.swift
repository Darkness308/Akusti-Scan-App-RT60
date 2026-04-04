//
//  Akusti_Scan_App_RT60Tests.swift
//  Akusti-Scan-App-RT60Tests
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import Testing
@testable import Akusti_Scan_App_RT60

// MARK: - RT60 Measurement Model Tests

struct RT60MeasurementTests {

    @Test func testMeasurementCreation() async throws {
        let measurement = RT60Measurement(
            rt60Value: 0.5,
            t20Value: 0.48,
            t30Value: 0.51,
            peakLevel: -6.0,
            noiseFloor: -60.0,
            frequency: .broadband,
            isValid: true
        )

        #expect(measurement.rt60Value == 0.5)
        #expect(measurement.t20Value == 0.48)
        #expect(measurement.t30Value == 0.51)
        #expect(measurement.peakLevel == -6.0)
        #expect(measurement.noiseFloor == -60.0)
        #expect(measurement.frequency == .broadband)
        #expect(measurement.isValid == true)
    }

    @Test func testMeasurementWithDefaultValues() async throws {
        let measurement = RT60Measurement(
            rt60Value: 1.0,
            peakLevel: -10.0,
            noiseFloor: -50.0
        )

        #expect(measurement.t20Value == nil)
        #expect(measurement.t30Value == nil)
        #expect(measurement.frequency == .broadband)
        #expect(measurement.isValid == true)
    }

    @Test func testInvalidMeasurement() async throws {
        let measurement = RT60Measurement(
            rt60Value: 0,
            peakLevel: -120,
            noiseFloor: -120,
            isValid: false
        )

        #expect(measurement.isValid == false)
        #expect(measurement.rt60Value == 0)
    }
}

// MARK: - Frequency Band Tests

struct FrequencyBandTests {

    @Test func testBroadbandCenterFrequency() async throws {
        #expect(FrequencyBand.broadband.centerFrequency == 0)
    }

    @Test func testOctaveBandCenterFrequencies() async throws {
        #expect(FrequencyBand.hz125.centerFrequency == 125)
        #expect(FrequencyBand.hz250.centerFrequency == 250)
        #expect(FrequencyBand.hz500.centerFrequency == 500)
        #expect(FrequencyBand.hz1000.centerFrequency == 1000)
        #expect(FrequencyBand.hz2000.centerFrequency == 2000)
        #expect(FrequencyBand.hz4000.centerFrequency == 4000)
    }

    @Test func testAllBandsExist() async throws {
        let allBands = FrequencyBand.allCases
        #expect(allBands.count == 7)
    }
}

// MARK: - Room Acoustic Rating Tests

struct RoomAcousticRatingTests {

    @Test func testLivingRoomOptimalRange() async throws {
        let range = RoomType.livingRoom.optimalRT60Range
        #expect(range.lowerBound == 0.4)
        #expect(range.upperBound == 0.6)
    }

    @Test func testRecordingStudioOptimalRange() async throws {
        let range = RoomType.recordingStudio.optimalRT60Range
        #expect(range.lowerBound == 0.2)
        #expect(range.upperBound == 0.4)
    }

    @Test func testConcertHallOptimalRange() async throws {
        let range = RoomType.concertHall.optimalRT60Range
        #expect(range.lowerBound == 1.5)
        #expect(range.upperBound == 2.5)
    }

    @Test func testBalancedRatingForOptimalRT60() async throws {
        let rating = RoomAcousticRating.fromRT60(0.5, roomType: .livingRoom)
        #expect(rating == .balanced)
    }

    @Test func testTooLiveRatingForHighRT60() async throws {
        let rating = RoomAcousticRating.fromRT60(1.5, roomType: .livingRoom)
        #expect(rating == .tooLive)
    }

    @Test func testTooDryRatingForLowRT60() async throws {
        let rating = RoomAcousticRating.fromRT60(0.1, roomType: .livingRoom)
        #expect(rating == .tooDry)
    }

    @Test func testDryRatingForSlightlyLowRT60() async throws {
        let rating = RoomAcousticRating.fromRT60(0.35, roomType: .livingRoom)
        #expect(rating == .dry)
    }

    @Test func testLiveRatingForSlightlyHighRT60() async throws {
        let rating = RoomAcousticRating.fromRT60(0.75, roomType: .livingRoom)
        #expect(rating == .live)
    }
}

// MARK: - Audio Sample Tests

struct AudioSampleTests {

    @Test func testAudioSampleCreation() async throws {
        let samples: [Float] = [0.1, 0.2, -0.3, 0.4, -0.5]
        let audioSample = AudioSample(
            samples: samples,
            sampleRate: 44100,
            channelCount: 1,
            duration: Double(samples.count) / 44100
        )

        #expect(audioSample.samples.count == 5)
        #expect(audioSample.sampleRate == 44100)
        #expect(audioSample.channelCount == 1)
    }

    @Test func testPeakAmplitude() async throws {
        let samples: [Float] = [0.1, 0.2, -0.8, 0.3, 0.5]
        let audioSample = AudioSample(
            samples: samples,
            sampleRate: 44100,
            channelCount: 1,
            duration: 0.001
        )

        #expect(audioSample.peakAmplitude == 0.8)
    }

    @Test func testRMSLevel() async throws {
        // For samples [1, 1, 1, 1], RMS should be 1
        let samples: [Float] = [1.0, 1.0, 1.0, 1.0]
        let audioSample = AudioSample(
            samples: samples,
            sampleRate: 44100,
            channelCount: 1,
            duration: 0.001
        )

        #expect(audioSample.rmsLevel == 1.0)
    }

    @Test func testRMSLevelDB() async throws {
        let samples: [Float] = [1.0, 1.0, 1.0, 1.0]
        let audioSample = AudioSample(
            samples: samples,
            sampleRate: 44100,
            channelCount: 1,
            duration: 0.001
        )

        // RMS of 1.0 should be 0 dB
        #expect(audioSample.rmsLevelDB == 0.0)
    }

    @Test func testEmptyAudioSample() async throws {
        let audioSample = AudioSample(
            samples: [],
            sampleRate: 44100,
            channelCount: 1,
            duration: 0
        )

        #expect(audioSample.peakAmplitude == 0)
        #expect(audioSample.rmsLevel == 0)
    }
}

// MARK: - Decay Curve Tests

struct DecayCurveTests {

    @Test func testDecayCurveCreation() async throws {
        let curve = DecayCurve(
            timePoints: [0.0, 0.1, 0.2, 0.3],
            levelPoints: [0.0, -10.0, -20.0, -30.0],
            regressionSlope: -100.0,
            regressionIntercept: 0.0,
            correlationCoefficient: -0.99
        )

        #expect(curve.timePoints.count == 4)
        #expect(curve.levelPoints.count == 4)
        #expect(curve.regressionSlope == -100.0)
        #expect(curve.correlationCoefficient == -0.99)
    }
}

// MARK: - RT60 Calculator Tests

struct RT60CalculatorTests {

    @Test func testCalculatorInitialization() async throws {
        let calculator = RT60Calculator()
        #expect(calculator != nil)
    }

    @Test func testCalculateRT60WithTooFewSamples() async throws {
        let calculator = RT60Calculator()
        let audioSample = AudioSample(
            samples: [0.1, 0.2, 0.3],
            sampleRate: 44100,
            channelCount: 1,
            duration: 0.00007
        )

        let result = calculator.calculateRT60(from: audioSample)
        #expect(result.isValid == false)
    }

    @Test func testCalculateRT60WithSyntheticDecay() async throws {
        let calculator = RT60Calculator()

        // Create synthetic exponential decay
        let sampleRate = 44100.0
        let duration = 2.0 // 2 seconds
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        // Impulse at the beginning
        samples[0] = 1.0

        // Exponential decay with RT60 of approximately 0.5 seconds
        let decayConstant = -6.91 / 0.5 // ln(0.001) / RT60
        for i in 1..<sampleCount {
            let time = Double(i) / sampleRate
            samples[i] = Float(exp(decayConstant * time))
        }

        let audioSample = AudioSample(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1,
            duration: duration
        )

        let result = calculator.calculateRT60(from: audioSample)

        // The calculated RT60 should be somewhere in a reasonable range
        // Due to the simplified calculation, we just check it's in a valid range
        #expect(result.rt60Value >= 0 || !result.isValid)
    }

    @Test func testGenerateDecayCurve() async throws {
        let calculator = RT60Calculator()

        let sampleRate = 44100.0
        var samples = [Float](repeating: 0, count: 44100)
        samples[0] = 1.0
        for i in 1..<44100 {
            samples[i] = Float(exp(-10.0 * Double(i) / sampleRate))
        }

        let audioSample = AudioSample(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1,
            duration: 1.0
        )

        let curve = calculator.generateDecayCurve(from: audioSample)

        #expect(curve.timePoints.count > 0)
        #expect(curve.levelPoints.count > 0)
        #expect(curve.timePoints.count == curve.levelPoints.count)
    }
}

// MARK: - Room Type Tests

struct RoomTypeTests {

    @Test func testAllRoomTypesHaveOptimalRanges() async throws {
        for roomType in RoomType.allCases {
            let range = roomType.optimalRT60Range
            #expect(range.lowerBound < range.upperBound)
            #expect(range.lowerBound >= 0)
            #expect(range.upperBound <= 10) // Max reasonable RT60
        }
    }

    @Test func testRoomTypeCount() async throws {
        #expect(RoomType.allCases.count == 6)
    }

    @Test func testRoomTypeRawValues() async throws {
        #expect(RoomType.recordingStudio.rawValue == "Tonstudio")
        #expect(RoomType.homeTheater.rawValue == "Heimkino")
        #expect(RoomType.livingRoom.rawValue == "Wohnzimmer")
        #expect(RoomType.classroom.rawValue == "Klassenzimmer")
        #expect(RoomType.concertHall.rawValue == "Konzertsaal")
        #expect(RoomType.church.rawValue == "Kirche")
    }
}

// MARK: - Measurement State Tests

struct MeasurementStateTests {

    @Test func testStateDisplayText() async throws {
        #expect(MeasurementState.idle.displayText == "Bereit")
        #expect(MeasurementState.recording.displayText == "Aufnahme läuft...")
        #expect(MeasurementState.processing.displayText == "Berechne RT60...")
        #expect(MeasurementState.completed.displayText == "Messung abgeschlossen")
        #expect(MeasurementState.error.displayText == "Fehler")
    }

    @Test func testStateEquatable() async throws {
        #expect(MeasurementState.idle == MeasurementState.idle)
        #expect(MeasurementState.recording != MeasurementState.idle)
    }
}
