//
//  Akusti_Scan_App_RT60Tests.swift
//  Akusti-Scan-App-RT60Tests
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import Testing
@testable import Akusti_Scan_App_RT60

// MARK: - Room Model Tests

struct RoomTests {
    @Test func roomVolumeCalculation() {
        let room = Room(width: 5.0, length: 7.0, height: 3.0)
        #expect(room.volume == 105.0)
    }

    @Test func roomSurfaceAreaCalculation() {
        let room = Room(width: 5.0, length: 7.0, height: 3.0)
        // 2 * (5*7 + 5*3 + 7*3) = 2 * (35 + 15 + 21) = 2 * 71 = 142
        #expect(room.totalSurfaceArea == 142.0)
    }

    @Test func speedOfSoundAtRoomTemperature() {
        let room = Room(temperature: 20.0)
        // c = 331.3 * sqrt(1 + 20/273.15) ≈ 343.2 m/s
        let expectedSpeed = 331.3 * (1 + 20.0 / 273.15).squareRoot()
        #expect(abs(room.speedOfSound - expectedSpeed) < 0.1)
    }

    @Test func roomFromLiDARDimensions() {
        let dimensions = RoomDimensions(
            width: 4.0,
            length: 6.0,
            height: 2.5,
            volume: 60.0,
            surfaceArea: 98.0
        )
        let room = Room.fromLiDAR(dimensions: dimensions, name: "Test Room")

        #expect(room.name == "Test Room")
        #expect(room.width == 4.0)
        #expect(room.length == 6.0)
        #expect(room.height == 2.5)
    }
}

// MARK: - Acoustic Material Tests

struct AcousticMaterialTests {
    @Test func concreteAbsorptionCoefficients() {
        let concrete = AcousticMaterial.concrete

        #expect(concrete.absorption(at: .hz125) == 0.01)
        #expect(concrete.absorption(at: .hz1000) == 0.02)
        #expect(concrete.absorption(at: .hz4000) == 0.03)
    }

    @Test func carpetAbsorptionCoefficients() {
        let carpet = AcousticMaterial.carpet

        // Carpet has high absorption at high frequencies
        #expect(carpet.absorption(at: .hz125) < carpet.absorption(at: .hz1000))
        #expect(carpet.absorption(at: .hz1000) > 0.5)
    }

    @Test func allMaterialsHaveAllBands() {
        for material in AcousticMaterial.materials {
            for band in FrequencyBand.allCases {
                let absorption = material.absorption(at: band)
                #expect(absorption >= 0.0 && absorption <= 1.0,
                       "\(material.name) has invalid absorption \(absorption) at \(band.rawValue)")
            }
        }
    }
}

// MARK: - Acoustics Calculator Tests

struct AcousticsCalculatorTests {
    let calculator = AcousticsCalculator()

    @Test func sabineRT60BasicCalculation() {
        // Simple room with known absorption
        var room = Room(width: 5.0, length: 7.0, height: 3.0)
        room.createDefaultSurfaces(
            floorMaterial: .concrete,
            ceilingMaterial: .concrete,
            wallMaterial: .concrete
        )

        let rt60 = calculator.sabineRT60(room: room)

        // RT60 should be positive and reasonable (0.1 - 10 seconds)
        for band in FrequencyBand.allCases {
            let value = rt60[band]!
            #expect(value > 0.1 && value < 10.0,
                   "RT60 at \(band.rawValue) should be in reasonable range, got \(value)")
        }
    }

    @Test func sabineRT60IncreasesWithVolume() {
        var smallRoom = Room(width: 3.0, length: 4.0, height: 2.5)
        smallRoom.createDefaultSurfaces(
            floorMaterial: .concrete,
            ceilingMaterial: .concrete,
            wallMaterial: .concrete
        )

        var largeRoom = Room(width: 10.0, length: 15.0, height: 5.0)
        largeRoom.createDefaultSurfaces(
            floorMaterial: .concrete,
            ceilingMaterial: .concrete,
            wallMaterial: .concrete
        )

        let smallRT60 = calculator.sabineRT60(room: smallRoom)[.hz1000]!
        let largeRT60 = calculator.sabineRT60(room: largeRoom)[.hz1000]!

        #expect(largeRT60 > smallRT60, "Larger room should have longer RT60")
    }

    @Test func sabineRT60DecreasesWithAbsorption() {
        var hardRoom = Room(width: 5.0, length: 7.0, height: 3.0)
        hardRoom.createDefaultSurfaces(
            floorMaterial: .concrete,
            ceilingMaterial: .concrete,
            wallMaterial: .concrete
        )

        var softRoom = Room(width: 5.0, length: 7.0, height: 3.0)
        softRoom.createDefaultSurfaces(
            floorMaterial: .carpet,
            ceilingMaterial: .acousticTile,
            wallMaterial: .curtains
        )

        let hardRT60 = calculator.sabineRT60(room: hardRoom)[.hz1000]!
        let softRT60 = calculator.sabineRT60(room: softRoom)[.hz1000]!

        #expect(softRT60 < hardRT60, "Room with more absorption should have shorter RT60")
    }

    @Test func eyringRT60BasicCalculation() {
        var room = Room(width: 5.0, length: 7.0, height: 3.0)
        room.createDefaultSurfaces(
            floorMaterial: .carpet,
            ceilingMaterial: .acousticTile,
            wallMaterial: .plasterOnBrick
        )

        let rt60 = calculator.eyringRT60(room: room)

        for band in FrequencyBand.allCases {
            let value = rt60[band]!
            #expect(value > 0.1 && value < 10.0,
                   "Eyring RT60 at \(band.rawValue) should be in reasonable range")
        }
    }

    @Test func eyringLessThanSabineForHighAbsorption() {
        var room = Room(width: 5.0, length: 7.0, height: 3.0)
        room.createDefaultSurfaces(
            floorMaterial: .carpet,
            ceilingMaterial: .acousticTile,
            wallMaterial: .curtains
        )

        let sabine = calculator.sabineRT60(room: room)[.hz1000]!
        let eyring = calculator.eyringRT60(room: room)[.hz1000]!

        // Eyring should give lower RT60 for high absorption rooms
        #expect(eyring <= sabine,
               "Eyring RT60 should be <= Sabine RT60 for high absorption rooms")
    }

    @Test func completeAnalysisReturnsAllFields() {
        var room = Room(name: "Test Room", width: 5.0, length: 7.0, height: 3.0)
        room.createDefaultSurfaces(
            floorMaterial: .woodFloor,
            ceilingMaterial: .plasterOnBrick,
            wallMaterial: .plasterOnBrick
        )

        let analysis = calculator.analyzeRoom(room: room)

        #expect(analysis.roomName == "Test Room")
        #expect(analysis.roomVolume == room.volume)
        #expect(analysis.roomSurfaceArea == room.totalSurfaceArea)
        #expect(!analysis.sabineRT60.isEmpty)
        #expect(!analysis.eyringRT60.isEmpty)
        #expect(analysis.qualityAssessment.count > 0)
    }
}

// MARK: - Frequency Band Tests

struct FrequencyBandTests {
    @Test func allBandsHaveCorrectFrequencies() {
        #expect(FrequencyBand.hz125.frequency == 125)
        #expect(FrequencyBand.hz250.frequency == 250)
        #expect(FrequencyBand.hz500.frequency == 500)
        #expect(FrequencyBand.hz1000.frequency == 1000)
        #expect(FrequencyBand.hz2000.frequency == 2000)
        #expect(FrequencyBand.hz4000.frequency == 4000)
    }

    @Test func sixOctaveBands() {
        #expect(FrequencyBand.allCases.count == 6)
    }
}

// MARK: - Room Surface Tests

struct RoomSurfaceTests {
    @Test func equivalentAbsorptionAreaCalculation() {
        let surface = RoomSurface(
            name: "Floor",
            area: 35.0,  // 5m x 7m
            material: .carpet
        )

        let eaa = surface.equivalentAbsorptionArea(at: .hz1000)
        let expected = 35.0 * AcousticMaterial.carpet.absorption(at: .hz1000)

        #expect(abs(eaa - expected) < 0.001)
    }
}

// MARK: - Acoustic Analysis Tests

struct AcousticAnalysisTests {
    @Test func qualityAssessmentCategories() {
        let calculator = AcousticsCalculator()

        // Very dry room (studio)
        var studioRoom = Room(width: 4.0, length: 5.0, height: 2.5)
        studioRoom.createDefaultSurfaces(
            floorMaterial: .carpet,
            ceilingMaterial: .acousticTile,
            wallMaterial: .acousticTile
        )
        let studioAnalysis = calculator.analyzeRoom(room: studioRoom)
        #expect(studioAnalysis.qualityAssessment.contains("trocken") ||
               studioAnalysis.qualityAssessment.contains("Studio") ||
               studioAnalysis.qualityAssessment.contains("Sprache"))

        // Large reverberant room
        var hallRoom = Room(width: 20.0, length: 30.0, height: 10.0)
        hallRoom.createDefaultSurfaces(
            floorMaterial: .concrete,
            ceilingMaterial: .concrete,
            wallMaterial: .concrete
        )
        let hallAnalysis = calculator.analyzeRoom(room: hallRoom)
        #expect(hallAnalysis.qualityAssessment.contains("hallig") ||
               hallAnalysis.qualityAssessment.contains("Konzert") ||
               hallAnalysis.qualityAssessment.contains("Kirche"))
    }

    @Test func averageRT60Calculation() {
        let sabineRT60: [FrequencyBand: Double] = [
            .hz125: 1.0,
            .hz250: 1.2,
            .hz500: 1.1,
            .hz1000: 1.0,
            .hz2000: 0.9,
            .hz4000: 0.8
        ]

        let analysis = AcousticAnalysis(
            roomName: "Test",
            roomVolume: 100,
            roomSurfaceArea: 150,
            sabineRT60: sabineRT60,
            eyringRT60: sabineRT60
        )

        let expectedAvg = (1.0 + 1.2 + 1.1 + 1.0 + 0.9 + 0.8) / 6.0
        #expect(abs(analysis.averageSabineRT60 - expectedAvg) < 0.001)
    }
}
