//
//  DataManager.swift
//  Akusti-Scan-App-RT60
//
//  SwiftData manager for measurements and rooms
//

import SwiftData
import Foundation

/// Manager for persisting and retrieving data
@MainActor
@Observable
final class DataManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Measurements

    /// Save a measurement
    func saveMeasurement(_ analysis: AcousticAnalysis, room: Room) {
        let record = MeasurementRecord(from: analysis, room: room)
        modelContext.insert(record)
        try? modelContext.save()
    }

    /// Fetch all measurements
    func fetchMeasurements() -> [MeasurementRecord] {
        let descriptor = FetchDescriptor<MeasurementRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch measurements for a specific room
    func fetchMeasurements(forRoom roomName: String) -> [MeasurementRecord] {
        let descriptor = FetchDescriptor<MeasurementRecord>(
            predicate: #Predicate { $0.roomName == roomName },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Delete a measurement
    func deleteMeasurement(_ record: MeasurementRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }

    /// Delete all measurements
    func deleteAllMeasurements() {
        let measurements = fetchMeasurements()
        for measurement in measurements {
            modelContext.delete(measurement)
        }
        try? modelContext.save()
    }

    // MARK: - Rooms

    /// Save or update a room
    func saveRoom(_ room: Room) {
        // Check if room exists
        let descriptor = FetchDescriptor<SavedRoom>(
            predicate: #Predicate { $0.id == room.id }
        )

        if let existingRoom = try? modelContext.fetch(descriptor).first {
            existingRoom.update(from: room)
        } else {
            let savedRoom = SavedRoom(from: room)
            modelContext.insert(savedRoom)
        }
        try? modelContext.save()
    }

    /// Fetch all saved rooms
    func fetchRooms() -> [SavedRoom] {
        let descriptor = FetchDescriptor<SavedRoom>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Delete a room
    func deleteRoom(_ room: SavedRoom) {
        modelContext.delete(room)
        try? modelContext.save()
    }

    // MARK: - Statistics

    /// Get measurement statistics
    func getStatistics() -> MeasurementStatistics {
        let measurements = fetchMeasurements()

        guard !measurements.isEmpty else {
            return MeasurementStatistics(
                totalMeasurements: 0,
                averageRT60: nil,
                minRT60: nil,
                maxRT60: nil,
                uniqueRooms: 0
            )
        }

        let rt60Values = measurements.map { $0.primaryRT60 }
        let uniqueRooms = Set(measurements.map { $0.roomName }).count

        return MeasurementStatistics(
            totalMeasurements: measurements.count,
            averageRT60: rt60Values.reduce(0, +) / Double(rt60Values.count),
            minRT60: rt60Values.min(),
            maxRT60: rt60Values.max(),
            uniqueRooms: uniqueRooms
        )
    }
}

/// Measurement statistics summary
struct MeasurementStatistics {
    let totalMeasurements: Int
    let averageRT60: Double?
    let minRT60: Double?
    let maxRT60: Double?
    let uniqueRooms: Int

    var hasData: Bool {
        totalMeasurements > 0
    }
}
