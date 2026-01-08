//
//  Room.swift
//  Akusti-Scan-App-RT60
//
//  Room model with acoustic properties
//

import Foundation

/// Material with absorption coefficients per frequency band
struct AcousticMaterial: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let absorptionCoefficients: [FrequencyBand: Double]

    init(id: UUID = UUID(), name: String, coefficients: [FrequencyBand: Double]) {
        self.id = id
        self.name = name
        self.absorptionCoefficients = coefficients
    }

    func absorption(at frequency: FrequencyBand) -> Double {
        absorptionCoefficients[frequency] ?? 0.1
    }
}

/// Standard frequency bands for acoustic analysis
enum FrequencyBand: String, CaseIterable, Codable, Sendable {
    case hz125 = "125 Hz"
    case hz250 = "250 Hz"
    case hz500 = "500 Hz"
    case hz1000 = "1 kHz"
    case hz2000 = "2 kHz"
    case hz4000 = "4 kHz"

    var frequency: Double {
        switch self {
        case .hz125: return 125
        case .hz250: return 250
        case .hz500: return 500
        case .hz1000: return 1000
        case .hz2000: return 2000
        case .hz4000: return 4000
        }
    }
}

/// Surface in a room with material assignment
struct RoomSurface: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var area: Double  // square meters
    var material: AcousticMaterial

    init(id: UUID = UUID(), name: String, area: Double, material: AcousticMaterial) {
        self.id = id
        self.name = name
        self.area = area
        self.material = material
    }

    func equivalentAbsorptionArea(at frequency: FrequencyBand) -> Double {
        area * material.absorption(at: frequency)
    }
}

/// Room model with all acoustic properties
struct Room: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var width: Double   // meters
    var length: Double  // meters
    var height: Double  // meters
    var surfaces: [RoomSurface]
    var temperature: Double  // Celsius
    var humidity: Double     // percentage (0-100)

    var volume: Double {
        width * length * height
    }

    var totalSurfaceArea: Double {
        2 * (width * length + width * height + length * height)
    }

    /// Speed of sound based on temperature
    var speedOfSound: Double {
        331.3 * sqrt(1 + temperature / 273.15)
    }

    /// Air absorption coefficient (depends on humidity and frequency)
    func airAbsorption(at frequency: FrequencyBand) -> Double {
        // Simplified air absorption model
        let f = frequency.frequency
        let h = humidity / 100.0

        // Air absorption increases with frequency squared
        let m = 5.5e-4 * pow(50.0 / h, 0.5) * pow(f / 1000.0, 1.7)
        return m
    }

    init(
        id: UUID = UUID(),
        name: String = "Neuer Raum",
        width: Double = 5.0,
        length: Double = 7.0,
        height: Double = 3.0,
        surfaces: [RoomSurface] = [],
        temperature: Double = 20.0,
        humidity: Double = 50.0
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.length = length
        self.height = height
        self.surfaces = surfaces
        self.temperature = temperature
        self.humidity = humidity
    }

    /// Create room from LiDAR dimensions
    static func fromLiDAR(dimensions: RoomDimensions, name: String = "Gescannter Raum") -> Room {
        Room(
            name: name,
            width: Double(dimensions.width),
            length: Double(dimensions.length),
            height: Double(dimensions.height)
        )
    }

    /// Create default surfaces for room
    mutating func createDefaultSurfaces(
        floorMaterial: AcousticMaterial,
        ceilingMaterial: AcousticMaterial,
        wallMaterial: AcousticMaterial
    ) {
        surfaces = [
            RoomSurface(name: "Boden", area: width * length, material: floorMaterial),
            RoomSurface(name: "Decke", area: width * length, material: ceilingMaterial),
            RoomSurface(name: "Wand vorne", area: width * height, material: wallMaterial),
            RoomSurface(name: "Wand hinten", area: width * height, material: wallMaterial),
            RoomSurface(name: "Wand links", area: length * height, material: wallMaterial),
            RoomSurface(name: "Wand rechts", area: length * height, material: wallMaterial)
        ]
    }
}

// MARK: - Predefined Materials

extension AcousticMaterial {
    /// Common acoustic materials with absorption coefficients
    static let materials: [AcousticMaterial] = [
        concrete,
        brick,
        plasterOnBrick,
        woodFloor,
        carpet,
        curtains,
        acousticTile,
        glass,
        plywood
    ]

    static let concrete = AcousticMaterial(
        name: "Beton",
        coefficients: [
            .hz125: 0.01, .hz250: 0.01, .hz500: 0.02,
            .hz1000: 0.02, .hz2000: 0.02, .hz4000: 0.03
        ]
    )

    static let brick = AcousticMaterial(
        name: "Ziegel",
        coefficients: [
            .hz125: 0.03, .hz250: 0.03, .hz500: 0.03,
            .hz1000: 0.04, .hz2000: 0.05, .hz4000: 0.07
        ]
    )

    static let plasterOnBrick = AcousticMaterial(
        name: "Putz auf Ziegel",
        coefficients: [
            .hz125: 0.01, .hz250: 0.02, .hz500: 0.02,
            .hz1000: 0.03, .hz2000: 0.04, .hz4000: 0.05
        ]
    )

    static let woodFloor = AcousticMaterial(
        name: "Holzboden",
        coefficients: [
            .hz125: 0.15, .hz250: 0.11, .hz500: 0.10,
            .hz1000: 0.07, .hz2000: 0.06, .hz4000: 0.07
        ]
    )

    static let carpet = AcousticMaterial(
        name: "Teppich",
        coefficients: [
            .hz125: 0.08, .hz250: 0.24, .hz500: 0.57,
            .hz1000: 0.69, .hz2000: 0.71, .hz4000: 0.73
        ]
    )

    static let curtains = AcousticMaterial(
        name: "Vorhänge",
        coefficients: [
            .hz125: 0.07, .hz250: 0.31, .hz500: 0.49,
            .hz1000: 0.75, .hz2000: 0.70, .hz4000: 0.60
        ]
    )

    static let acousticTile = AcousticMaterial(
        name: "Akustikdecke",
        coefficients: [
            .hz125: 0.20, .hz250: 0.40, .hz500: 0.70,
            .hz1000: 0.80, .hz2000: 0.60, .hz4000: 0.40
        ]
    )

    static let glass = AcousticMaterial(
        name: "Glas",
        coefficients: [
            .hz125: 0.35, .hz250: 0.25, .hz500: 0.18,
            .hz1000: 0.12, .hz2000: 0.07, .hz4000: 0.04
        ]
    )

    static let plywood = AcousticMaterial(
        name: "Sperrholz",
        coefficients: [
            .hz125: 0.28, .hz250: 0.22, .hz500: 0.17,
            .hz1000: 0.09, .hz2000: 0.10, .hz4000: 0.11
        ]
    )
}
