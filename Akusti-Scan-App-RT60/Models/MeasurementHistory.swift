//
//  MeasurementHistory.swift
//  Akusti-Scan-App-RT60
//
//  SwiftData models for persisting measurements
//

import SwiftData
import Foundation

/// Persisted measurement record
@Model
final class MeasurementRecord {
    var id: UUID
    var timestamp: Date
    var roomName: String
    var roomVolume: Double
    var roomSurfaceArea: Double

    // RT60 values per frequency band (stored as JSON)
    var measuredRT60Data: Data?
    var sabineRT60Data: Data?
    var eyringRT60Data: Data?

    // Summary values
    var averageMeasuredRT60: Double?
    var averageSabineRT60: Double
    var averageEyringRT60: Double
    var qualityAssessment: String

    // Room dimensions
    var roomLength: Double
    var roomWidth: Double
    var roomHeight: Double

    init(from analysis: AcousticAnalysis, room: Room) {
        self.id = analysis.id
        self.timestamp = analysis.timestamp
        self.roomName = analysis.roomName
        self.roomVolume = analysis.roomVolume
        self.roomSurfaceArea = analysis.roomSurfaceArea
        self.averageMeasuredRT60 = analysis.averageMeasuredRT60
        self.averageSabineRT60 = analysis.averageSabineRT60
        self.averageEyringRT60 = analysis.averageEyringRT60
        self.qualityAssessment = analysis.qualityAssessment
        self.roomLength = room.length
        self.roomWidth = room.width
        self.roomHeight = room.height

        // Encode frequency band data
        let encoder = JSONEncoder()
        self.measuredRT60Data = try? encoder.encode(analysis.measuredRT60)
        self.sabineRT60Data = try? encoder.encode(analysis.sabineRT60)
        self.eyringRT60Data = try? encoder.encode(analysis.eyringRT60)
    }

    // Decode RT60 values
    var measuredRT60: [FrequencyBand: Double]? {
        guard let data = measuredRT60Data else { return nil }
        return try? JSONDecoder().decode([FrequencyBand: Double].self, from: data)
    }

    var sabineRT60: [FrequencyBand: Double] {
        guard let data = sabineRT60Data else { return [:] }
        return (try? JSONDecoder().decode([FrequencyBand: Double].self, from: data)) ?? [:]
    }

    var eyringRT60: [FrequencyBand: Double] {
        guard let data = eyringRT60Data else { return [:] }
        return (try? JSONDecoder().decode([FrequencyBand: Double].self, from: data)) ?? [:]
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: timestamp)
    }

    var primaryRT60: Double {
        averageMeasuredRT60 ?? averageSabineRT60
    }

    var formattedRT60: String {
        String(format: "%.2f s", primaryRT60)
    }
}

/// Persisted room configuration
@Model
final class SavedRoom {
    var id: UUID
    var name: String
    var length: Double
    var width: Double
    var height: Double
    var temperature: Double
    var humidity: Double
    var surfacesData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(from room: Room) {
        self.id = room.id
        self.name = room.name
        self.length = room.length
        self.width = room.width
        self.height = room.height
        self.temperature = room.temperature
        self.humidity = room.humidity
        self.createdAt = Date()
        self.updatedAt = Date()

        let encoder = JSONEncoder()
        self.surfacesData = try? encoder.encode(room.surfaces)
    }

    func toRoom() -> Room {
        var room = Room(
            id: id,
            name: name,
            width: width,
            length: length,
            height: height,
            temperature: temperature,
            humidity: humidity
        )

        if let data = surfacesData,
           let surfaces = try? JSONDecoder().decode([RoomSurface].self, from: data) {
            room.surfaces = surfaces
        }

        return room
    }

    func update(from room: Room) {
        self.name = room.name
        self.length = room.length
        self.width = room.width
        self.height = room.height
        self.temperature = room.temperature
        self.humidity = room.humidity
        self.updatedAt = Date()

        let encoder = JSONEncoder()
        self.surfacesData = try? encoder.encode(room.surfaces)
    }
}
